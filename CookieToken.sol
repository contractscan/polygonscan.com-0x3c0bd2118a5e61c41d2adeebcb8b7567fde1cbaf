/**
 * This is a rewards token for the game CryptoCookie
 * You cant play at https://cryptocookiesdao.com/
 * 
 **/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "./ERC20.sol";
import "./ERC20Burnable.sol";
import "./Ownable.sol";

import "./IUniswapV2Router02.sol";
import "./IUniswapV2Factory.sol";

/**
 * After deploying this contract, ownership will be transfer to the game, and
 * only the game will mint tokens to give players rewards
 */
contract CookieToken is ERC20, ERC20Burnable, Ownable {
    address public treasury;
    IUniswapV2Router02 immutable public router;

    // sending tokens to this address will add a fee to the transaction
    mapping(address => bool) public hasFee;
    // this addressess will be able to withdraw their tokens without a fee
    mapping(address => bool) public freeFee;
    // whis will record for each transaction
    mapping(address => uint256) public lastTransfer;
    uint256 public minSellTime = 30 days;

    event SetTreasury(address treasury);
    event SetFreeFee(address to, bool free);
    event SetHasFee(address to, bool has);
    event Minselltime(uint selltime);
    event SwapToTreasury(uint[] amounts);

    constructor(uint256 _initialSupply, IUniswapV2Router02 _router) ERC20("Cookie", "CKIE") {
        router = _router;
        _approve(address(this), address(_router), type(uint256).max);
        setFreeFee(address(this), true);
        setFreeFee(owner(), true);
        address pair = IUniswapV2Factory(_router.factory()).createPair(_router.WETH(), address(this));
        setHasFee(pair, true);

        _mint(msg.sender, _initialSupply);
    }

    function mint(address _to, uint256 _amount) external onlyOwner {
        _mint(_to, _amount);
    }

    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
        emit SetTreasury(_treasury);
    }

    function setFreeFee(address _to, bool _free) public onlyOwner {
        freeFee[_to] = _free;
        emit SetFreeFee(_to, _free);
    }

    function setHasFee(address _to, bool _has) public onlyOwner {
        hasFee[_to] = _has;
        emit SetHasFee(_to, _has);
    }

    function setSellTime(uint256 _minSellTime) external onlyOwner {
        minSellTime = _minSellTime;
        emit Minselltime(_minSellTime);
    }

    function haveTax(address _user) public view returns(bool) {
        return block.timestamp - lastTransfer[_user] < minSellTime;
    }

    // if selling in a time lapse smaller than 30 days a 5% goes to the treasury
    function _transfer(address _from, address _to, uint256 _amount) internal override {
        if (hasFee[_to] && !freeFee[_from] && treasury != address(0)) {
            if (haveTax(_from)) {
                uint256 comision = _amount * 500 / 10000; // 5% fee
                _amount -= comision;
                super._transfer(_from, address(this), comision);
                _swapToTreasury(comision);
            }
            lastTransfer[_from] = block.timestamp;
        }

        super._transfer(_from, _to, _amount);
    }

    function _swapToTreasury(uint256 _comision) internal {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();

        emit SwapToTreasury(
            router.swapExactTokensForETH(
                _comision,
                0,
                path,
                treasury,
                type(uint256).max
            )
        );
    }
}