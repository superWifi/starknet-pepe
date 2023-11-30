use pepe::Pepe::Pepe;
use starknet::contract_address_const;
use starknet::ContractAddress;
use starknet::get_block_timestamp;
use starknet::testing::{set_caller_address, set_block_timestamp};
use integer::u256;
use integer::u256_from_felt252;
use integer::BoundedInt;
use traits::Into;
use array::ArrayTrait;
use result::ResultTrait;
use debug::PrintTrait;

//
// Constants
//

const NAME: felt252 = 111;
const SYMBOL: felt252 = 222;

//
// Helper functions
//

fn setup() -> (ContractAddress, u256) {
    let initial_supply: u256 = Pepe::block_reward();
    let account: ContractAddress = contract_address_const::<1>();
    // Set account as default caller
    set_caller_address(account);

    let cur_block_timestamp = get_block_timestamp();
    set_block_timestamp(cur_block_timestamp + Pepe::block_time());

    let block_reward = Pepe::block_reward();

    Pepe::_mint(account, block_reward);

    Pepe::constructor(NAME, SYMBOL);
    (account, initial_supply)
}

fn set_caller_as_zero() {
    set_caller_address(contract_address_const::<0>());
}

//
// Tests
//

#[test]
#[available_gas(2000000)]
fn test_initializer() {
    Pepe::initializer(NAME, SYMBOL);

    assert(Pepe::name() == NAME, 'Name should be NAME');
    assert(Pepe::symbol() == SYMBOL, 'Symbol should be SYMBOL');
    assert(Pepe::decimals() == 18, 'Decimals should be 18');
    assert(Pepe::totalSupply() == u256_from_felt252(0), 'Supply should eq 0');
    assert(true, 'Name should be NAME');
}


#[test]
#[available_gas(2000000)]
fn test_constructor() {
    let initial_supply: u256 = u256_from_felt252(0);
    let account: ContractAddress = contract_address_const::<1>();
    let decimals: u8 = 18;

    Pepe::constructor(NAME, SYMBOL);

    assert(Pepe::totalSupply() == initial_supply, 'Should eq inital_supply');
    assert(Pepe::name() == NAME, 'Name should be NAME');
    assert(Pepe::symbol() == SYMBOL, 'Symbol should be SYMBOL');
    assert(Pepe::decimals() == decimals, 'Decimals should be 18');
}

#[test]
#[available_gas(2000000)]
fn test_approve() {
    let (owner, supply) = setup();
    let spender: ContractAddress = contract_address_const::<2>();
    let amount: u256 = u256_from_felt252(100);

    let success: bool = Pepe::approve(spender, amount);
    assert(success, 'Should return true');
    assert(Pepe::allowance(owner, spender) == amount, 'Spender not approved correctly');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Pepe: approve from 0', ))]
fn test_approve_from_zero() {
    let (owner, supply) = setup();
    let spender: ContractAddress = contract_address_const::<2>();
    let amount: u256 = u256_from_felt252(100);

    set_caller_as_zero();

    Pepe::approve(spender, amount);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Pepe: approve to 0', ))]
fn test_approve_to_zero() {
    let (owner, supply) = setup();
    let spender: ContractAddress = contract_address_const::<0>();
    let amount: u256 = u256_from_felt252(100);

    Pepe::approve(spender, amount);
}

#[test]
#[available_gas(2000000)]
fn test__approve() {
    let (owner, supply) = setup();

    let spender: ContractAddress = contract_address_const::<2>();
    let amount: u256 = u256_from_felt252(100);

    Pepe::_approve(owner, spender, amount);
    assert(Pepe::allowance(owner, spender) == amount, 'Spender not approved correctly');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Pepe: approve from 0', ))]
fn test__approve_from_zero() {
    let owner: ContractAddress = contract_address_const::<0>();
    let spender: ContractAddress = contract_address_const::<1>();
    let amount: u256 = u256_from_felt252(100);
    Pepe::_approve(owner, spender, amount);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Pepe: approve to 0', ))]
fn test__approve_to_zero() {
    let (owner, supply) = setup();

    let spender: ContractAddress = contract_address_const::<0>();
    let amount: u256 = u256_from_felt252(100);
    Pepe::_approve(owner, spender, amount);
}

#[test]
#[available_gas(2000000)]
fn test_transfer() {
    let (sender, supply) = setup();

    let recipient: ContractAddress = contract_address_const::<2>();
    let amount: u256 = u256_from_felt252(100);
    let success: bool = Pepe::transfer(recipient, amount);

    assert(success, 'Should return true');
    assert(Pepe::balanceOf(recipient) == amount, 'Balance should eq amount');
    assert(Pepe::balanceOf(sender) == supply - amount, 'Should eq supply - amount');
    assert(Pepe::totalSupply() == supply, 'Total supply should not change');
}

#[test]
#[available_gas(2000000)]
fn test__transfer() {
    let (sender, supply) = setup();

    let recipient: ContractAddress = contract_address_const::<2>();
    let amount: u256 = u256_from_felt252(100);
    Pepe::_transfer(sender, recipient, amount);

    assert(Pepe::balanceOf(recipient) == amount, 'Balance should eq amount');
    assert(Pepe::balanceOf(sender) == supply - amount, 'Should eq supply - amount');
    assert(Pepe::totalSupply() == supply, 'Total supply should not change');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('u256_sub Overflow', ))]
fn test__transfer_not_enough_balance() {
    let (sender, supply) = setup();

    let recipient: ContractAddress = contract_address_const::<2>();
    let amount: u256 = supply + u256_from_felt252(1);
    Pepe::_transfer(sender, recipient, amount);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Pepe: transfer from 0', ))]
fn test__transferFrom_zero() {
    let sender: ContractAddress = contract_address_const::<0>();
    let recipient: ContractAddress = contract_address_const::<1>();
    let amount: u256 = u256_from_felt252(100);
    Pepe::_transfer(sender, recipient, amount);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Pepe: transfer to 0', ))]
fn test__transfer_to_zero() {
    let (sender, supply) = setup();

    let recipient: ContractAddress = contract_address_const::<0>();
    let amount: u256 = u256_from_felt252(100);
    Pepe::_transfer(sender, recipient, amount);
}

#[test]
#[available_gas(2000000)]
fn test_transferFrom() {
    let (owner, supply) = setup();

    let recipient: ContractAddress = contract_address_const::<2>();
    let spender: ContractAddress = contract_address_const::<3>();
    let amount: u256 = u256_from_felt252(100);

    Pepe::approve(spender, amount);

    set_caller_address(spender);

    let success: bool = Pepe::transferFrom(owner, recipient, amount);
    assert(success, 'Should return true');

    // Will dangle without setting as a var
    let spender_allowance: u256 = Pepe::allowance(owner, spender);

    assert(Pepe::balanceOf(recipient) == amount, 'Should eq amount');
    assert(Pepe::balanceOf(owner) == supply - amount, 'Should eq suppy - amount');
    assert(spender_allowance == u256_from_felt252(0), 'Should eq 0');
    assert(Pepe::totalSupply() == supply, 'Total supply should not change');
}

#[test]
#[available_gas(2000000)]
fn test_transferFrom_doesnt_consume_infinite_allowance() {
    let (owner, supply) = setup();

    let recipient: ContractAddress = contract_address_const::<2>();
    let spender: ContractAddress = contract_address_const::<3>();
    let amount: u256 = u256_from_felt252(100);

    Pepe::approve(spender, BoundedInt::max());

    set_caller_address(spender);
    Pepe::transferFrom(owner, recipient, amount);

    let spender_allowance: u256 = Pepe::allowance(owner, spender);
    assert(spender_allowance == BoundedInt::max(), 'Allowance should not change');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('u256_sub Overflow', ))]
fn test_transferFrom_greater_than_allowance() {
    let (owner, supply) = setup();

    let recipient: ContractAddress = contract_address_const::<2>();
    let spender: ContractAddress = contract_address_const::<3>();
    let amount: u256 = u256_from_felt252(100);
    let amount_plus_one: u256 = amount + u256_from_felt252(1);

    Pepe::approve(spender, amount);

    set_caller_address(spender);

    Pepe::transferFrom(owner, recipient, amount_plus_one);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Pepe: transfer to 0', ))]
fn test_transferFrom_to_zero_address() {
    let (owner, supply) = setup();

    let recipient: ContractAddress = contract_address_const::<0>();
    let spender: ContractAddress = contract_address_const::<3>();
    let amount: u256 = u256_from_felt252(100);

    Pepe::approve(spender, amount);

    set_caller_address(spender);

    Pepe::transferFrom(owner, recipient, amount);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('u256_sub Overflow', ))]
fn test_transferFrom_from_zero_address() {
    let (owner, supply) = setup();

    let zero_address: ContractAddress = contract_address_const::<0>();
    let recipient: ContractAddress = contract_address_const::<2>();
    let spender: ContractAddress = contract_address_const::<3>();
    let amount: u256 = u256_from_felt252(100);

    set_caller_address(zero_address);

    Pepe::transferFrom(owner, recipient, amount);
}

#[test]
#[available_gas(2000000)]
fn test_increase_allowance() {
    let (owner, supply) = setup();

    let spender: ContractAddress = contract_address_const::<2>();
    let amount: u256 = u256_from_felt252(100);

    Pepe::approve(spender, amount);
    let success: bool = Pepe::increase_allowance(spender, amount);
    assert(success, 'Should return true');

    let spender_allowance: u256 = Pepe::allowance(owner, spender);
    assert(spender_allowance == amount + amount, 'Should be amount * 2');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Pepe: approve to 0', ))]
fn test_increase_allowance_to_zero_address() {
    let (owner, supply) = setup();

    let spender: ContractAddress = contract_address_const::<0>();
    let amount: u256 = u256_from_felt252(100);

    Pepe::increase_allowance(spender, amount);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Pepe: approve from 0', ))]
fn test_increase_allowance_from_zero_address() {
    let (owner, supply) = setup();

    let zero_address: ContractAddress = contract_address_const::<0>();
    let spender: ContractAddress = contract_address_const::<2>();
    let amount: u256 = u256_from_felt252(100);

    set_caller_address(zero_address);

    Pepe::increase_allowance(spender, amount);
}

#[test]
#[available_gas(2000000)]
fn test_decrease_allowance() {
    let (owner, supply) = setup();

    let spender: ContractAddress = contract_address_const::<2>();
    let amount: u256 = u256_from_felt252(100);

    Pepe::approve(spender, amount);
    let success: bool = Pepe::decrease_allowance(spender, amount);
    assert(success, 'Should return true');

    let spender_allowance: u256 = Pepe::allowance(owner, spender);
    assert(spender_allowance == amount - amount, 'Should be 0');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('u256_sub Overflow', ))]
fn test_decrease_allowance_to_zero_address() {
    let (owner, supply) = setup();

    let spender: ContractAddress = contract_address_const::<0>();
    let amount: u256 = u256_from_felt252(100);

    Pepe::decrease_allowance(spender, amount);
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('u256_sub Overflow', ))]
fn test_decrease_allowance_from_zero_address() {
    let (owner, supply) = setup();

    let zero_address: ContractAddress = contract_address_const::<0>();
    let spender: ContractAddress = contract_address_const::<2>();
    let amount: u256 = u256_from_felt252(100);

    set_caller_address(zero_address);

    Pepe::decrease_allowance(spender, amount);
}

#[test]
#[available_gas(2000000)]
fn test__spend_allowance_not_unlimited() {
    let (owner, supply) = setup();

    let spender: ContractAddress = contract_address_const::<2>();
    let amount: u256 = u256_from_felt252(100);

    Pepe::_approve(owner, spender, supply);
    Pepe::_spend_allowance(owner, spender, amount);
    assert(Pepe::allowance(owner, spender) == supply - amount, 'Should eq supply - amount');
}

#[test]
#[available_gas(2000000)]
fn test__spend_allowance_unlimited() {
    let (owner, supply) = setup();

    let spender: ContractAddress = contract_address_const::<2>();
    let max_minus_one: u256 = BoundedInt::max() - 1.into();

    Pepe::_approve(owner, spender, BoundedInt::max());
    Pepe::_spend_allowance(owner, spender, max_minus_one);

    assert(
        Pepe::allowance(owner, spender) == BoundedInt::max(), 'Allowance should not change'
    );
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('max supply reached', ))]
fn test_mint_max_supply() {
    let max_supply = Pepe::max_supply();
    let block_reward = Pepe::block_reward();
    Pepe::_total_supply::write(max_supply - block_reward + u256_from_felt252(1));

    let minter: ContractAddress = contract_address_const::<2>();
    Pepe::_mint(minter, block_reward);
}

#[test]
#[available_gas(2000000)]
fn test__add_candidate() {
    Pepe::constructor(NAME, SYMBOL);
    let minter: ContractAddress = contract_address_const::<1>();
    let minter2: ContractAddress = contract_address_const::<2>();

    // add minter
    assert(Pepe::is_mint_candidate(minter) == false, 'minter is not candidate');
    Pepe::_add_candidate(minter);
    assert(Pepe::is_mint_candidate(minter) == true, 'mintter is candidate');
    assert(Pepe::_mint_candidates_count::read() == 1, 'Should eq 1');
    assert(Pepe::_mint_candidates::read(minter) == 1, 'mint flag');
    assert(Pepe::_mint_candidates_index::read(1) == minter, 'mint index');

    // add minter2
    assert(Pepe::is_mint_candidate(minter2) == false, 'minter2 is not candidate');
    Pepe::_add_candidate(minter2);
    assert(Pepe::is_mint_candidate(minter) == true, 'mint2 is candidate');
    assert(Pepe::_mint_candidates_count::read() == 2, 'Should eq 2');
    assert(Pepe::_mint_candidates::read(minter2) == 1, 'mint2 flag');
    assert(Pepe::_mint_candidates_index::read(2) == minter2, 'mint2 index');

    // repeat add
    Pepe::_add_candidate(minter);
    assert(Pepe::_mint_candidates_count::read() == 2, 'Should eq 2');

    // clear minter candidates
    let mint_flag = Pepe::_mint_flag::read();
    Pepe::_clear_candidates();
    assert(Pepe::_mint_candidates_count::read() == 0, 'Should eq 0');
    assert(Pepe::_mint_flag::read() == mint_flag + 1, 'Should eq mint flag');
    assert(Pepe::is_mint_candidate(minter) == false, 'minter is not candidate');
    assert(Pepe::is_mint_candidate(minter2) == false, 'minter2 is not candidate');
}

#[test]
#[available_gas(20000000)]
fn test__try_mint() {
    Pepe::constructor(NAME, SYMBOL);

    let minter: ContractAddress = contract_address_const::<1>();
    let minter2: ContractAddress = contract_address_const::<2>();

    let mint_count = Pepe::mint_count();

    // no candidates
    Pepe::_try_mint();
    assert(Pepe::mint_count() == mint_count, 'Should eq 0');

    // no available_count
    assert(Pepe::available_mint_count() == 0_u64, 'availeble_mint_count eq 0');
    Pepe::_add_candidate(minter);
    Pepe::_try_mint();
    assert(Pepe::balanceOf(minter) == 0, 'Should eq 0');
    assert(Pepe::mint_count() == mint_count, 'Should eq 0');

    let cur_block_timestamp = get_block_timestamp();
    set_block_timestamp(cur_block_timestamp + Pepe::block_time());

    // 1 candidate and 1 available_mint_count
    let block_reward = Pepe::block_reward();
    assert(Pepe::mint_candidates_count() == 1, 'Should eq 1');
    assert(Pepe::available_mint_count() == 1, 'availeble_mint_count eq 1');
    Pepe::_try_mint();
    assert(Pepe::mint_candidates_count() == 0, 'Should eq 1');
    assert(Pepe::available_mint_count() == 0, 'availeble_mint_count eq 0');
    assert(Pepe::balanceOf(minter) == block_reward, 'mint award');
    assert(Pepe::mint_candidates_count() == 0, 'Should eq 0');

    // 2 candidate and 1 available_mint_count
    let cur_block_timestamp = get_block_timestamp();
    set_block_timestamp(cur_block_timestamp + Pepe::block_time());
    assert(Pepe::available_mint_count() == 1, 'availeble_mint_count eq 1');

    Pepe::_add_candidate(minter);
    Pepe::_add_candidate(minter2);
    assert(Pepe::mint_candidates_count() == 2, 'Should eq 2');
    Pepe::_try_mint();
    assert(Pepe::balanceOf(minter) + Pepe::balanceOf(minter2) == block_reward * 2, 'mint award');
    assert(Pepe::mint_candidates_count() == 0, 'Should eq 0');

    // 2 candidate and 3 available_count
    let cur_block_timestamp = get_block_timestamp();
    set_block_timestamp(cur_block_timestamp + Pepe::block_time() * 3);
    assert(Pepe::available_mint_count() == 3, 'availeble_mint_count eq 3');

    Pepe::_add_candidate(minter);
    Pepe::_add_candidate(minter2);
    assert(Pepe::mint_candidates_count() == 2, 'Should eq 2');
    Pepe::_try_mint();
    assert(Pepe::balanceOf(minter) + Pepe::balanceOf(minter2) == block_reward * 4, 'mint award');

    assert(Pepe::totalSupply() == block_reward * 4, 'Should eq total supply');
}

#[test]
#[available_gas(2000000)]
fn test_available_supply() {
    assert(Pepe::available_mint_count() == 0, 'Should eq 0');

    let n = 10;
    let cur_block_timestamp = get_block_timestamp();
    set_block_timestamp(cur_block_timestamp + n * Pepe::block_time());

    assert(Pepe::available_mint_count() == n, 'Should eq n');
}

#[test]
#[available_gas(2000000)]
fn test_block_reward() -> u64 {
    let mut n = 0;
    let mut block_reward = u256_from_felt252(10000000000000000000000);
    let block_halve_interval = Pepe::block_halve_interval();
    loop {
        if n == 10 {
            assert(
                Pepe::block_reward() == u256_from_felt252(10000000000000000000),
                'block_reward shoudl halve'
            );
            break n;
        }
        assert(Pepe::block_reward() == block_reward, 'block_reward shoudl halve');
        block_reward /= u256_from_felt252(2);
        n += 1;
        Pepe::_mint_count::write(block_halve_interval * n);
    }
}

//#[test]
//#[available_gas(2000000)]
//#[should_panic(expected: ('Pepe: mint to 0', ))]
//fn test__mint_to_zero() {
//    let minter: ContractAddress = contract_address_const::<0>();
//
//    Pepe::_mint(minter);
//}

#[test]
#[available_gas(2000000)]
fn test__burn() {
    let (owner, supply) = setup();

    let amount: u256 = u256_from_felt252(100);
    Pepe::_burn(owner, amount);

    assert(Pepe::totalSupply() == supply - amount, 'Should eq supply - amount');
    assert(Pepe::balanceOf(owner) == supply - amount, 'Should eq supply - amount');
}

#[test]
#[available_gas(2000000)]
#[should_panic(expected: ('Pepe: burn from 0', ))]
fn test__burn_from_zero() {
    setup();
    let zero_address: ContractAddress = contract_address_const::<0>();
    let amount: u256 = u256_from_felt252(100);

    Pepe::_burn(zero_address, amount);
}
