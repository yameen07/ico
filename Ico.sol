// SPDX-License-Identifier: MIT
pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC20/PausableToken.sol";
import "openzeppelin-solidity/contracts/token/ERC20/MintableToken.sol";
import "openzeppelin-solidity/contracts/token/ERC20/TokenTimelock.sol";
import "openzeppelin-solidity/contracts/crowdsale/Crowdsale.sol";
import "openzeppelin-solidity/contracts/crowdsale/emission/MintedCrowdsale.sol";
import "openzeppelin-solidity/contracts/crowdsale/validation/CappedCrowdsale.sol";
import "openzeppelin-solidity/contracts/crowdsale/validation/TimedCrowdsale.sol";
import "openzeppelin-solidity/contracts/crowdsale/validation/WhitelistedCrowdsale.sol";
import "openzeppelin-solidity/contracts/crowdsale/distribution/RefundableCrowdsale.sol";

contract Ico is Crowdsale, MintedCrowdsale, CappedCrowdsale, TimedCrowdsale, WhitelistedCrowdsale, RefundableCrowdsale {

  // Track investor contributions
  uint256 public investorMinCap = 5000000000000000000000000; 
  uint256 public investorHardCap = 12500000000000000000000000; 
  mapping(address => uint256) public contributions;

  // Crowdsale Stages
  enum CrowdsaleStage { PreICO, ICO }
  // Default to presale stage
  CrowdsaleStage public stage = CrowdsaleStage.PreICO;

  // Token Distribution
  uint256 public reservePercentage = 30;
  uint256 public interestPercentage = 20;
  uint256 public teamMemberPercentage = 10;
  uint256 public generalFundPercentage = 13;
  uint256 public bountyPercentage = 2;
  uint256 public tokenSalePercentage = 25;

  // Token reserve funds
  address public reserveFund;
  address public interestFund;
  address public teamMemberFund;
  address public generalFund;
  address public bountyFund;
  address public tokenSaleFund;

  // Token time lock
  address public reserveTimelock;
  address public interestTimelock;
  address public teamMemberTimelock;
  address public generalTimelock;
  address public bountyTimelock;
  address public tokenSaleTimelock;

  constructor(
    uint256 _rate,
    address _wallet,
    ERC20 _token,
    uint256 _cap,
    uint256 _openingTime,
    uint256 _closingTime,
    uint256 _goal,
    address _reserveFund,
    address _interestFund,
    address _teamMemberFund,
    address _generalFund,
    address _bountyFund,
    address _tokenSaleFund,
    uint256 _releaseTime
  )
    Crowdsale(_rate, _wallet, _token)
    CappedCrowdsale(_cap)
    TimedCrowdsale(_openingTime, _closingTime)
    RefundableCrowdsale(_goal)
    public
  {
    require(_goal <= _cap);
     
    reserveFund   = _reserveFund;
    interestFund = _interestFund;
    teamMemberFund =_teamMemberFund;
    generalFund = _generalFund;
    bountyFund  = _bountyFund;
    tokenSaleFund = _tokenSaleFund;

    releaseTime    = _releaseTime;

  }

  
  // Returns the amount contributed so far by a sepecific user.
    function getUserContribution(address _beneficiary)
    public view returns (uint256)
  {
    return contributions[_beneficiary];
  }

  
 // Allows admin to update the crowdsale stage
 
  function setCrowdsaleStage(uint _stage) public onlyOwner {
    if(uint(CrowdsaleStage.PreICO) == _stage) {
      stage = CrowdsaleStage.PreICO;
    } else if (uint(CrowdsaleStage.ICO) == _stage) {
      stage = CrowdsaleStage.ICO;
    }

    if(stage == CrowdsaleStage.PreICO) {
      rate = 1000000000000000;
    } else if (stage == CrowdsaleStage.ICO) {
      rate = 1000000000000000;
    }
  }

 //forwards funds to the wallet during the PreICO stage, then the refund vault during ICO stage
   
  function _forwardFunds() internal {
    if(stage == CrowdsaleStage.PreICO) {
      wallet.transfer(msg.value);
    } else if (stage == CrowdsaleStage.ICO) {
      super._forwardFunds();
    }
  }


  // Extend parent behavior requiring purchase to respect investor min/max funding cap.
  
  function _preValidatePurchase(
    address _beneficiary,
    uint256 _weiAmount
  )
    internal
  {
    super._preValidatePurchase(_beneficiary, _weiAmount);
    uint256 _existingContribution = contributions[_beneficiary];
    uint256 _newContribution = _existingContribution.add(_weiAmount);
    require(_newContribution >= investorMinCap && _newContribution <= investorHardCap);
    contributions[_beneficiary] = _newContribution;
  }


  
  // enables token transfers, called when owner calls finalize()
 
  function finalization() internal {
    if(goalReached()) {
      MintableToken _mintableToken = MintableToken(token);
      uint256 _alreadyMinted = _mintableToken.totalSupply();

      uint256 _finalTotalSupply = _alreadyMinted.div(tokenSalePercentage).mul(100);

      reserveTimelock   = new TokenTimelock(token, reserveFund, releaseTime);
      interestTimelock = new TokenTimelock(token, interestFund, releaseTime);
      teamMemberTimelock   = new TokenTimelock(token, teamMemberFund, releaseTime);
      generalTimelock = new TokenTimelock(token, generalFund, releaseTime);
      bountyTimelock = new TokenTimelock(token, bountyFund, releaseTime);
      tokenSaleTimelock = new TokenTimelock(token, tokenSaleFund, releaseTime);


      _mintableToken.mint(address(reserveTimelock),   _finalTotalSupply.mul(reservePercentage).div(100));
      _mintableToken.mint(address(interestTimelock), _finalTotalSupply.mul(interestPercentage).div(100));
      _mintableToken.mint(address(teamMemberTimelock),   _finalTotalSupply.mul(teamMemberPercentage).div(100));
      _mintableToken.mint(address(generalTimelock),   _finalTotalSupply.mul(generalPercentage).div(100));
      _mintableToken.mint(address(bountyTimelock),   _finalTotalSupply.mul(bountyPercentage).div(100));
      _mintableToken.mint(address(tokenSaleTimelock),   _finalTotalSupply.mul(tokenSalePercentage).div(100));

      _mintableToken.finishMinting();
      // Unpause the token
      PausableToken _pausableToken = PausableToken(token);
      _pausableToken.unpause();
      _pausableToken.transferOwnership(wallet);
    }

    super.finalization();
  }

}