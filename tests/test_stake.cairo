%lang starknet
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.syscalls import get_block_timestamp, get_contract_address
from starkware.cairo.common.uint256 import Uint256, uint256_add, uint256_sub, uint256_signed_nn, uint256_signed_lt, uint256_eq


from src.stake import vault_balance, user_balance, deposit, withdraw
from src.interfaces.ierc20 import IERC20

@contract_interface
namespace IStake:
    func deposit(amount : Uint256, token_address : felt) -> ():
    end

    func withdraw(amount : Uint256) -> (current_amount : Uint256):
    end

    func get_balance() -> (balance : Uint256):
    end
end

@external
func test_deposit{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
}():
    alloc_locals

    local token_address = 9999

    %{ stop_mock1 = mock_call(ids.token_address, "transferFrom", [1]) %}
    %{ stop_mock2 = mock_call(ids.token_address, "approve", [1]) %}

    # check user balance
    %{ stop_prank_callable = start_prank(111) %}  
    let (cur_bal_1_a) = user_balance.read(111)

    let (is_zero) = uint256_eq(cur_bal_1_a,  Uint256(0,0))
    assert is_zero = 1

    deposit(Uint256(500,0), token_address)
    let (cur_bal_1_b) = user_balance.read(111)
    let (is_500) = uint256_eq(cur_bal_1_b, Uint256(500,0))
    assert is_500 = 1

 
    deposit(Uint256(1000,0), token_address)
    let (cur_bal_2) = user_balance.read(111)
    let (is_1500) = uint256_eq(cur_bal_2, Uint256(1500,0))
    assert is_1500 = 1

    %{ 
        stop_prank_callable()
        stop_mock1()
        stop_mock2()
     %} 

    return ()
end

@external
func test_withdraw{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
}():
    alloc_locals
    local token_address = 9999

    %{ stop_mock1 = mock_call(ids.token_address, "transfer", [1]) %}
    %{ stop_mock2 = mock_call(ids.token_address, "approve", [1]) %}
    %{ stop_mock3 = mock_call(ids.token_address, "transferFrom", [1]) %}

    %{ stop_prank_callable = start_prank(111) %}  

    let (cur_bal_1_b) = user_balance.read(111)
    let (is_zero) = uint256_eq(cur_bal_1_b,  Uint256(0,0))
    assert is_zero = 1

   deposit(Uint256(1200,0), token_address)
    let (cur_bal_1_c) = user_balance.read(111)
    let (is_1200) = uint256_eq(cur_bal_1_c,  Uint256(1200,0))
    assert is_1200 = 1

    withdraw(Uint256(200,0))
    let (cur_bal_1_d) = user_balance.read(111)
    let (is_1000) = uint256_eq(cur_bal_1_d,  Uint256(1000,0))
    assert is_1000 = 1

    %{
        stop_prank_callable() 
        stop_mock1()
        stop_mock2()
        stop_mock3()
    %}

    return ()

end

@external
func test_withdraw_more_than_allowed{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
}():
    alloc_locals
    local token_address = 9999

    %{ stop_mock1 = mock_call(ids.token_address, "transfer", [1]) %}
    %{ stop_mock2 = mock_call(ids.token_address, "approve", [1]) %}
    %{ stop_mock3 = mock_call(ids.token_address, "transferFrom", [1]) %}

    %{ stop_prank_callable = start_prank(111) %}  
    let (cur_bal_1_b) = user_balance.read(111)
    let (is_zero) = uint256_eq(cur_bal_1_b,  Uint256(0,0))
    assert is_zero = 1

    deposit(Uint256(1200,0), token_address)
    let (cur_bal_1_c) = user_balance.read(111)
    let (is_1200) = uint256_eq(cur_bal_1_c,  Uint256(1200,0))
    assert is_1200 = 1

    %{ expect_revert("TRANSACTION_FAILED", "withdraw amount exceeds your deposited amount")%}
    withdraw(Uint256(1500,0))
   
     %{
        stop_prank_callable() 
        stop_mock1()
        stop_mock2()
        stop_mock3()
    %}
    return ()

end



@external
func test_stake_with_deploy{syscall_ptr : felt*, range_check_ptr}():
    alloc_locals

    local contract_address : felt
    %{ids.contract_address = deploy_contract("./src/stake.cairo").contract_address %}

    %{ stop_prank_callable = start_prank(111) %}  

    local erc20A_address: felt

    local this_contract_address = 123
    %{ mint_quantity = [10 ** 18, 0]%}
    %{ids.erc20A_address = deploy_contract('./src/mockups/erc20.cairo', [11, 11, 18, mint_quantity[0], mint_quantity[1], 111]).contract_address  %}
    %{ids.erc20A_address = ids.erc20A_address  %}
    %{print(f"Token minted") %}

  


    let (res1) = IStake.get_balance(contract_address=contract_address)
    let (is_zero) = uint256_eq(res1, Uint256(0,0))
    assert is_zero = 1
    

    let (balA) = IERC20.balanceOf(erc20A_address, this_contract_address)
    %{print('balance', ids.balA.low)%}
    %{stop_prank_callable() %}

    %{ stop_prank = start_prank(111, ids.erc20A_address) %}
    IERC20.approve(erc20A_address, contract_address, Uint256(200,0)) 
    %{ stop_prank() %}

    %{ stop_prank = start_prank(111, ids.contract_address) %}
    IStake.deposit(contract_address, Uint256(200,0), erc20A_address)
    let (res2) = IStake.get_balance(contract_address=contract_address)
    %{print('balance', ids.res2.low)%}
    let (is_200) = uint256_eq(res2, Uint256(200,0))
    assert is_200 = 1    
    %{ stop_prank() %}

    %{ stop_prank = start_prank(111, ids.contract_address) %}
    IStake.withdraw(contract_address, Uint256(50,0))
    let (res3) = IStake.get_balance(contract_address=contract_address)
    %{print('balance', ids.res3.low)%}
    let (is_150) = uint256_eq(res3, Uint256(150,0))
    assert is_150 = 1  
    %{ stop_prank() %}

    return ()
end