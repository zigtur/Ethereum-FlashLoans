// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

import { FlashLoanReceiverBase } from "./FlashLoanReceiverBase.sol";
import { ILendingPool, ILendingPoolAddressesProvider, IERC20 } from "./Interfaces.sol";
import { SafeMath } from "./Libraries.sol";
import "./Ownable.sol";

/*
* A contract that executes the following logic in a single atomic transaction:
*
*   1. Gets a batch flash loan of AAVE, DAI and LINK
*   2. Deposits all of this flash liquidity onto the Aave V2 lending pool
*   3. Borrows 100 LINK based on the deposited collateral
*   4. Repays 100 LINK and unlocks the deposited collateral
*   5. Withdrawls all of the deposited collateral (AAVE/DAI/LINK)
*   6. Repays batch flash loan including the 9bps fee
*
*/
contract BatchFlashDemo is FlashLoanReceiverBase, Ownable {
    
    ILendingPoolAddressesProvider provider;
    using SafeMath for uint256;
    uint256 flashWethAmt0;
    address lendingPoolAddr;
    
    // fuji reserve asset addresses
    address fujiWeth = 0x9668f5f55f2712Dd2dfa316256609b516292D554;

    uint256 sentBacktoMe = 500000000000000000;


    //fuji Address Provider = 0x7fdC1FdF79BE3309bf82f4abdAD9f111A6590C0f
    
    // intantiate lending pool addresses provider and get lending pool address
    constructor(ILendingPoolAddressesProvider _addressProvider) FlashLoanReceiverBase(_addressProvider) public {
        provider = _addressProvider;
        lendingPoolAddr = provider.getLendingPool();
    }

    /**
        This function is called after your contract has received the flash loaned amount
     */
    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    )
        external
        override
        returns (bool)
    {
        //fujiWeth.call(abi.encodeWithSignature("mint(uint256)", 1 ether));
        address _owner = owner();
        fujiWeth.call(abi.encodeWithSignature("transfer(address,uint256)", _owner, sentBacktoMe));
        // Approve the LendingPool contract allowance to *pull* the owed amount
        // i.e. AAVE V2's way of repaying the flash loan
        for (uint i = 0; i < assets.length; i++) {
            uint amountOwing = amounts[i].add(premiums[i]);
            IERC20(assets[i]).approve(address(_lendingPool), amountOwing);
        }

        return true;
    }
    

    /*
    * This function is manually called to commence the flash loans sequence
    */
    function executeFlashLoan() public onlyOwner {
        address receiverAddress = address(this);

        // the various assets to be flashed
        address[] memory assets = new address[](1);
        assets[0] = fujiWeth;
        
        // the amount to be flashed for each asset
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1 ether;
        
        flashWethAmt0 = 1 ether;
        

        // 0 = no debt, 1 = stable, 2 = variable
        uint256[] memory modes = new uint256[](1);
        modes[0] = 0;

        address onBehalfOf = address(this);
        bytes memory params = "";
        uint16 referralCode = 0;

        _lendingPool.flashLoan(
            receiverAddress,
            assets,
            amounts,
            modes,
            onBehalfOf,
            params,
            referralCode
        );
    }
    
        
    /*
    * Rugpull all ERC20 tokens from the contract
    */
    function rugPull() public payable onlyOwner {
        
        // withdraw all ETH
        msg.sender.call{ value: address(this).balance }("");
        
        // withdraw all x ERC20 tokens
        IERC20(fujiWeth).transfer(msg.sender, IERC20(fujiWeth).balanceOf(address(this)));
    }
    
}