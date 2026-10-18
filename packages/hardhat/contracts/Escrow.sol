// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

// 只声明我们要用的三个函数。Escrow 通过这个接口去调用任何 ERC20 合约。
interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract Escrow {
    // ---------- 状态机 ----------
    enum Status { Created, Paid, Completed, Refunded, Disputed }
    struct Order {
        address buyer;
        address seller;
        address token;      // 用哪种 ERC20 结算
        uint256 amount;     // 最小单位
        uint256 deadline;   // unix 时间戳，秒
        Status status;
        string description;
    }

    // ---------- 存储 ----------
    address public arbiter;
    uint256 public orderCount;
    mapping(uint256 => Order) private _orders;

    // ---------- 事件 ----------
    event OrderCreated(uint256 indexed id, address indexed buyer, address indexed seller, address token, uint256 amount, uint256 deadline);
    event OrderPaid(uint256 indexed id);
    event OrderCompleted(uint256 indexed id);
    event OrderRefunded(uint256 indexed id);
    event OrderDisputed(uint256 indexed id, address by);
    event OrderResolved(uint256 indexed id, bool sellerWins);

    // ---------- 修饰器 ----------
    modifier onlyArbiter() {
        require(msg.sender == arbiter, "Escrow: caller is not the arbiter");
        _;
    }

    modifier onlyBuyer(uint256 id) {
        require(msg.sender == _orders[id].buyer, "Escrow: caller is not the buyer");
        _;
    }

    modifier inStatus(uint256 id, Status s) {
        require(_orders[id].status == s, "Escrow: wrong status");
        _;
    }

    constructor(address _arbiter) {
        require(_arbiter != address(0), "Escrow: arbiter is the zero address");
        arbiter = _arbiter;
    }

    function getOrder(uint256 id) public view returns (Order memory) {
        require(id < orderCount, "Escrow: order does not exist");
        return _orders[id];
    }

    // ---------- TODO 1：创建订单 ----------
    // 要求：seller 不能是零地址、不能是自己；amount 大于 0；deadline 必须在未来；
    // 订单 id 为当前 orderCount，写入 _orders，orderCount 加一；
    // buyer 是 msg.sender，状态 Created；发出 OrderCreated；返回 id。
    function createOrder(address seller, address token, uint256 amount, uint256
    deadline, string memory description) public returns (uint256) {
        //先检查seller是否为零地址或自己
        require(seller != address(0) && seller != msg.sender, "Escrow:The seller can't be a zero address, and it also can't be yourself");
        //再检查amount是否大于0
        require(amount > 0, "Escrow:The amount must be greater than 0");
        //最后检查deadline是否在未来
        require(deadline > block.timestamp, "Escrow:The deadline must be in the future");

        //执行创建订单操作
        uint256 id = orderCount;
        _orders[id] = Order(msg.sender, seller, token, amount, deadline, Status.Created, description);
        orderCount++;

        //发出OrderCreated事件
        emit OrderCreated(id, msg.sender, seller, token, amount, deadline);
        return id;
    }

    // ---------- TODO 2：买家付款 ----------
    // 要求：只有买家、只在 Created 状态（用修饰器）；
    // 先把状态改为 Paid，再调用代币的 transferFrom 把 amount 从买家转到本合约
    // transferFrom 返回 false 要 revert；发出 OrderPaid。
    // 提示：IERC20(o.token).transferFrom(...)。想清楚代币合约看到的 msg.sender 是谁。
    function deposit(uint256 id) public onlyBuyer(id) inStatus(id, Status.Created) {
        //先把状态改为Paid
        _orders[id].status = Status.Paid;

        //再调用代币的transferFrom把amount从买家转到本合约
        Order storage o = _orders[id];
        require(IERC20(o.token).transferFrom(o.buyer, address(this), o.amount), "Escrow: transferFrom failed");

        //发出OrderPaid事件
        emit OrderPaid(id);
    }

    // ---------- TODO 3：买家确认收货 ----------
    // 要求：只有买家、只在 Paid 状态；状态改为 Completed；代币转给卖家；发出
    // OrderCompleted。
    function confirm(uint256 id) public onlyBuyer(id) inStatus(id, Status.Paid) {
        //状态改为Completed
        _orders[id].status = Status.Completed;

        //代币转给卖家
        Order storage o = _orders[id];
        require(IERC20(o.token).transfer(o.seller, o.amount), "Escrow: transfer to seller failed");

        //发出OrderCompleted事件
        emit OrderCompleted(id);
    }

    // ---------- TODO 4：超期退款 ----------
    // 要求：只有买家、只在 Paid 状态；block.timestamp 必须大于 deadline；
    // 状态改为 Refunded；代币退回买家；发出 OrderRefunded。
    function refund(uint256 id) public onlyBuyer(id) inStatus(id, Status.Paid) {
        //检查是否超期
        require(block.timestamp > _orders[id].deadline, "Escrow: deadline not yet passed");

        //状态改为Refunded
        _orders[id].status = Status.Refunded;

        //代币退回买家
        Order storage o = _orders[id];
        require(IERC20(o.token).transfer(o.buyer, o.amount), "Escrow: refund to buyer failed");

        //发出OrderRefunded事件
        emit OrderRefunded(id);
    }

    // ---------- TODO 5：发起争议 ----------
    // 要求：只在 Paid 状态；调用者必须是买家或卖家；状态改为 Disputed；发出
    // OrderDisputed。
    function dispute(uint256 id) public inStatus(id, Status.Paid) {
        //检查调用者是否为买家或卖家
        Order storage o = _orders[id];
        require(msg.sender == o.buyer || msg.sender == o.seller, "Escrow: caller is not buyer or seller");

        //状态改为Disputed
        o.status = Status.Disputed;

        //发出OrderDisputed事件
        emit OrderDisputed(id, msg.sender);
    }

    // ---------- TODO 6：仲裁 ----------
    // 要求：只有仲裁人、只在 Disputed 状态；
    // sellerWins 为 true 则状态 Completed、代币给卖家，否则状态 Refunded、代币
    // 退买家；
    // 发出 OrderResolved。
    function resolve(uint256 id, bool sellerWins) public onlyArbiter inStatus(id, Status.Disputed) {
        Order storage o = _orders[id];

        if (sellerWins) {
            //状态改为Completed，代币给卖家
            o.status = Status.Completed;
            require(IERC20(o.token).transfer(o.seller, o.amount), "Escrow: transfer to seller failed");
        } else {
            //状态改为Refunded，代币退买家
            o.status = Status.Refunded;
            require(IERC20(o.token).transfer(o.buyer, o.amount), "Escrow: refund to buyer failed");
        }
        
        //发出OrderResolved事件
        emit OrderResolved(id, sellerWins);
    }
}
