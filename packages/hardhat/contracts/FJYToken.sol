// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

contract FJYToken {
// ---------- 元数据 ----------
string public name = "FJYToken";
string public symbol = "FJY202430550391";
uint8 public decimals = 18;
uint256 public totalSupply;

// ---------- 权限 ----------
address public owner;

modifier onlyOwner() {
require(msg.sender == owner, "FJYToken: caller is not the owner");
_;
}

// ---------- 状态 ----------
// 这两个 mapping 就是"账本"。代币不存在于任何钱包里，只存在于这里。
mapping(address => uint256) private _balances;
mapping(address => mapping(address => uint256)) private _allowances;

// ---------- 事件 ----------
event Transfer(address indexed from, address indexed to, uint256 value);
event Approval(address indexed owner, address indexed spender, uint256 value);

constructor() {
owner = msg.sender;
}

// ---------- 只读查询 ----------
function balanceOf(address account) public view returns (uint256) {
return _balances[account];
}

function allowance(address _owner, address spender) public view returns (uint256) {
return _allowances[_owner][spender];
}

// ---------- TODO 1：转账 ----------
// 要求：to 不能是零地址；msg.sender 余额必须足够；
// 扣 msg.sender、加 to；发出 Transfer 事件；返回 true。
function transfer(address to, uint256 value) public returns (bool) {
    //先检查to是否为零地址
    require(to != address(0),"FJYToken:cannot transfer to the zero address");
    //再检查msg.sender余额是否充足
    require(balanceOf(msg.sender) >= value,"FJYToken:The sender doesn't have enough balance");

    //执行转账操作
    _balances[msg.sender] -= value;
    _balances[to] += value;
    emit Transfer(msg.sender,to,value);

    return true;
}

// ---------- TODO 2：授权 ----------
// 要求：记录 msg.sender 允许 spender 花 value；发出 Approval 事件；返回 true。
function approve(address spender, uint256 value) public returns (bool) {
    _allowances[msg.sender][spender] = value;
    emit Approval(msg.sender,spender,value);
    return true;
}

// ---------- TODO 3：代扣转账 ----------
// 要求：from 的余额必须足够；msg.sender 在 from 处的额度必须足够；
// 额度减 value；扣 from、加 to；发出 Transfer 事件；返回 true。
function transferFrom(address from, address to, uint256 value) public returns (bool) {
    //先检查from的余额是否充足
    require(balanceOf(from) >= value,"FJYToken:The sender doesn't have enough balance");
    //再检查msg.sender在from处的额度是否充足
    require(allowance(from, msg.sender) >= value,"FJYToken:Insufficient limit at the source");

    //执行代扣转账操作
    _allowances[from][msg.sender] -= value;
    _balances[from] -= value;
    _balances[to] += value;
    emit Transfer(from,to,value);

    return true;
}

// ---------- TODO 4：增发（只有 owner 能调） ----------
// 要求：to 不能是零地址；totalSupply 加 value；to 余额加 value；
// 发出 Transfer 事件，from 填 address(0)。
function mint(address to, uint256 value) public onlyOwner {
    //检查to是否为零地址
    require(to != address(0),"FJYToken:cannot transfer to the zero address");

    //执行增发操作
    totalSupply += value;
    _balances[to] += value;
    emit Transfer(address(0),to,value);
}

// ---------- TODO 5：销毁自己的代币 ----------
// 要求：msg.sender 余额必须足够；余额减 value；totalSupply 减 value；
// 发出 Transfer 事件，to 填 address(0)。
function burn(uint256 value) public {
    //检查msg.sender余额是否充足
    require(balanceOf(msg.sender) >= value,"FJYToken:The sender doesn't have enough balance");

    //执行销毁操作
    _balances[msg.sender] -= value;
    totalSupply -= value;
    emit Transfer(msg.sender,address(0),value);
}
}
