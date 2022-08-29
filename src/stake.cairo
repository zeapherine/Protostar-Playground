
%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address
from starkware.cairo.common.math import assert_not_zero, assert_le
from starkware.cairo.common.uint256 import Uint256, uint256_add, uint256_sub, uint256_signed_nn, uint256_signed_lt


from src.interfaces.ierc20 import IERC20

@storage_var
func vault_balance() -> (bal : Uint256):
end

@storage_var
func user_balance(user : felt) -> (bal : Uint256):
end

@storage_var
func token_A_address() -> (address : felt):
end

@external
func deposit{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
}(amount : Uint256, token_address : felt) -> ():
    let (caller) = get_caller_address()

    token_A_address.write(token_address)

    let (bal) = vault_balance.read()
    let (caller_bal) = user_balance.read(caller)

    let (amt1 : Uint256, _) = uint256_add(bal, amount)
    vault_balance.write(amt1)

    let (amt2 : Uint256, _) = uint256_add(caller_bal, amount)
    user_balance.write(caller, amt2)

    let (vault_address) = get_contract_address()

    IERC20.transferFrom(token_address, caller, vault_address, amount)
    return ()
end

@view
func get_balance{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
}() -> (balance : Uint256):
    let (caller) = get_caller_address()
    let (caller_bal) = user_balance.read(caller)
    return (balance = caller_bal)
end

@external
func withdraw{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
}(amount : Uint256) -> (current_amount : Uint256):

    alloc_locals 

    let (caller) = get_caller_address()
    let (vault_address) = get_contract_address()
    let (caller_bal : Uint256, ) = user_balance.read(caller)

    let (amt2) = uint256_signed_lt(amount, caller_bal)
    with_attr error_message("withdraw amount exceeds your deposited amount"):
        assert_not_zero(amt2)
    end

    let (vault_bal : Uint256) = vault_balance.read()
    let (bal1 : Uint256) = uint256_sub(vault_bal, amount)
    vault_balance.write(bal1)

    
    let (bal2 : Uint256) = uint256_sub(caller_bal, amount)
    user_balance.write(caller, bal2)
    let (caller_bal_current) = user_balance.read(caller)

    let (token_address) = token_A_address.read()

    IERC20.approve(token_address, caller, amount)
    IERC20.transfer(token_address, caller, amount)

    return (current_amount = caller_bal_current)
end