// SPDX-License-Identifier: MIT
pragma solidity ^0.6;
import "libs/ERC20.sol";
import "libs/Ownable.sol";

interface IDepositContract {
    event DepositEvent(
        bytes pubkey,
        bytes withdrawal_credentials,
        bytes amount,
        bytes signature,
        bytes index
    );
    function deposit(
        bytes calldata pubkey,
        bytes calldata withdrawal_credentials,
        bytes calldata signature,
        bytes32 deposit_data_root
    ) external payable;

    /// @notice Query the current deposit root hash.
    /// @return The deposit root hash.
    function get_deposit_root() external view returns (bytes32);

    /// @notice Query the current deposit count.
    /// @return The deposit count encoded as a little endian 64-bit number.
    function get_deposit_count() external view returns (bytes memory);
}
interface IOracle {
    /// @notice Query the exchange rate between ETH and CETH2.
    /// @return The exchange rate.
    function exchangeRate() external view returns (uint);
}
contract miningShare is ERC20,Ownable{
    using SafeMath for uint256;
    address private _minerKeeper;
    enum miningMachineStates{Building,Suspended,Completed,Mining}
    struct MiningMachine{
        uint id;
        uint totalAmount;
        uint minersCount;
       miningMachineStates states;
        mapping(address=>uint) deposit;
    }
    struct Investors{
        uint[] ids;
        uint[] amount;
    }
     event DepositEvent(
        address account,
        uint ethAmount,
        uint creth2Amount
    );

    event WithdrawEvent(
        address account,
        uint ethAmount,
        uint creth2Amount
    );

    event StakeEvent(
        bytes pubkey,
        bytes withdrawal_credentials,
        bytes signature
    );
    event CreateEvent(
        uint number,
        bytes msg
        );

    IDepositContract public constant eth2DepositContract = IDepositContract(0x00000000219ab540356cBB839Cbe05303d7705Fa);
    uint public cap;
    uint public accumulated = 0;
    bool public breaker = false;
    MiningMachine[] private stope;
    mapping(address=>Investors) users;
      constructor() public ERC20("BETH","BETH"){
        cap = 32000*1e18;
    }
    
    function create() public onlyOwner  returns(uint)  {
        MiningMachine memory mm;
        mm.id = stope.length;
        mm.totalAmount = 0;
        mm.minersCount = 0;
        mm.states = miningMachineStates.Building;
        stope.push(mm);
        emit CreateEvent(stope.length,"Created");
        return stope.length;
        
    }
    
    function getUserInfo() external view returns(uint[] memory ids,uint[]memory amounts,uint blance){
       return (users[msg.sender].ids,users[msg.sender].amount,balanceOf(msg.sender));
    }
    
    function machineInfo(uint mid) external view returns(uint totalAmount,uint minersCount ){
     require(stope.length>mid,"invalid index");
     return (stope[mid].totalAmount,stope[mid].minersCount);
    }
    function getMachineCount() external view returns(uint mcount){
        return stope.length;
    }
    
       function setBreaker(bool _breaker)  external  onlyOwner{
      
        breaker = _breaker;
    }
     function deposit(uint mid) external payable {
        require(breaker == false, "breaker");
        require(stope.length>mid,"invalid index");
        require(msg.value>0,"invalid amount");
        require(accumulated <= cap, "cap exceeded");
        accumulated = accumulated.add(msg.value);
        uint TKAmount = msg.value.mul(100);
        uint cindex = isExist(mid);
        if(cindex==999){
            users[msg.sender].ids.push(mid);
            users[msg.sender].amount.push(msg.value);
        }else {
           
            users[msg.sender].amount[cindex]= users[msg.sender].amount[cindex].add(msg.value) ;
        }

        _mint(msg.sender, TKAmount);
        stope[mid].totalAmount=stope[mid].totalAmount.add(msg.value);
        stope[mid].minersCount++;
        stope[mid].deposit[msg.sender]= stope[mid].deposit[msg.sender].add(msg.value);
        emit DepositEvent(msg.sender, msg.value,TKAmount);
    }

     function isExist(uint mid) internal view returns(uint){
        for(uint  i = 0 ;i<users[msg.sender].ids.length;i++){
            if(users[msg.sender].ids[i]==mid){
                return i;
            }
        }
        return 999;
    }
    function withdraw(uint Amount) external onlyOwner {
        if(Amount==0) Amount = address(this).balance;
        //require(address(this).balance >=Amount,"invalid Amount");
        msg.sender.transfer(Amount);
        accumulated = accumulated.sub(Amount);
      
    }
}
