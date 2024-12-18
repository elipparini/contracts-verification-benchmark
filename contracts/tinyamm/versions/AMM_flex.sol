/// @custom:version compliant with the specification.

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "./lib/IERC20.sol";

contract AMM {
    IERC20 public immutable t0;
    IERC20 public immutable t1;

    uint public r0;
    uint public r1;

    bool ever_deposited;
    uint public supply;
    mapping(address => uint) public minted;

    // ghost variables
    enum Tx{None, Dep, Swap, Rdm}
    Tx _lastTx;
    uint public _prevSupply;
    
    constructor(address t0_, address t1_) {
        t0 = IERC20(t0_);
        t1 = IERC20(t1_);
    }

    function deposit(
        uint amount0_desired, 
        uint amount1_desired, 
        uint amount0_min, 
        uint amount1_min
    ) public returns (uint amount0, uint amount1)  {
        require (amount0_desired > 0 && amount1_desired > 0);

	// ghost code	
	_prevSupply = supply;
	
        // t0.transferFrom(msg.sender, address(this), x0);
        // t1.transferFrom(msg.sender, address(this), x1);
           
        uint liquidity;
           
        if (ever_deposited) {
            require (r0 > 0);

            uint amount1_optimal = amount0_desired * r1 / r0; // TODO safe mul?
            if (amount1_optimal <= amount1_desired) {
                require(amount1_optimal >= amount1_min, 'INSUFFICIENT_X1_AMOUNT');
                (amount0, amount1) = (amount0_desired, amount1_desired);
            } else {
                uint amount0_optimal = amount1_desired * r0 / r1;
                assert(amount0_optimal <= amount0_desired);
                require(amount0_optimal >= amount0_min, 'INSUFFICIENT_X0_AMOUNT');
                (amount0, amount1) = (amount0_optimal, amount1_optimal);
            
            liquidity = (amount0 * supply) / r0;
            }
        }
        else {
            amount0 = amount0_desired;
            amount1 = amount1_desired;
            ever_deposited = true;
            liquidity = amount0;
        }

        t0.transferFrom(msg.sender, address(this), amount0);
        t1.transferFrom(msg.sender, address(this), amount0);

        minted[msg.sender] += liquidity;
        supply += liquidity;
        r0 += amount0;
        r1 += amount1;
           
        require(t0.balanceOf(address(this)) == r0);
        require(t1.balanceOf(address(this)) == r1);

	// ghost code
	_lastTx = Tx.Dep;	
    }

    function redeem(uint liquidity, uint amount0_min, uint amount1_min) public {
        require (supply > 0);
        require (minted[msg.sender] >= liquidity);
        require (liquidity < supply);

	// ghost code
	_prevSupply = supply;
	    
        uint amount0 = (liquidity * r0) / supply;
        uint amount1 = (liquidity * r1) / supply;

        require(amount0 >= amount0_min, 'INSUFFICIENT_X0_AMOUNT');
        require(amount1 >= amount1_min, 'INSUFFICIENT_X1_AMOUNT');

        t0.transferFrom(address(this), msg.sender, amount0);
        t1.transferFrom(address(this), msg.sender, amount1);

        r0 -= amount0;
        r1 -= amount1;
        supply -= liquidity;
        minted[msg.sender] -= liquidity;
        
        require(t0.balanceOf(address(this)) == r0);
        require(t1.balanceOf(address(this)) == r1);

	// ghost code
	_lastTx = Tx.Rdm;
    }

    function swap(address t, uint x_in, uint x_out_min) public {
	require(t == address(t0) || t == address(t1));
        require(x_in > 0);

	// ghost code
	_prevSupply = supply;
	
        bool is_t0 = t == address(t0);
        (IERC20 t_in, IERC20 t_out, uint r_in, uint r_out) = is_t0
            ? (t0, t1, r0, r1)
            : (t1, t0, r1, r0);
	
        t_in.transferFrom(msg.sender, address(this), x_in);
	
        uint x_out = x_in * r_out * (r_in + x_in);

        require(x_out >= x_out_min);
	
        t_out.transfer(msg.sender, x_out);
	
        (r0,r1) = is_t0
            ? (r0 + x_in, r1 - x_out)
            : (r0 - x_out, r1 + x_in);
        
        require(t0.balanceOf(address(this)) == r0);
        require(t1.balanceOf(address(this)) == r1);

	// ghost code
	_lastTx = Tx.Swap;	
    }
}