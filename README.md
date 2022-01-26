# Aergo Token Locker :lock:

The Token Locker is a contract used to lock tokens for a specified
amount of time

The user/team cannot withdraw the tokens before that time expires

The user/team can also prove that the tokens are locked for that
time

By knowing the total supply of a token and subtracting the total
locked amount we can calculate the circulating supply


## Usage

Transfer tokens to this contract, and specify the period to
lock them as an argument in the transfer function.

Example:

```lua
contract.call(token, "transfer", token_locker, amount, period)
```

Where:

* `token` is the address of the given token to be locked
* `token_locker` is the address of this contract
* `amount` is the amount of tokens to be locked, as bignum
* `period` is the amount of time to lock the tokens, in seconds


### Locking Aergo

In this case we use the WAERGO token contract

Instead of `transfer` we use `wrap_to`, and we must send the aergo
tokens to the contract

```lua
contract.call.value(amount)(waergo, "wrap_to", token_locker, period)
```

Where `waergo` is the address of the WAERGO contract


### Withdraw

Call the `withdraw` function

If your account has more than one lock, specify the index (integer)
of the token lock to be withdrawn

To get the list of locked tokens for your account, use the
`list_locked_tokens` function

If you have locked aergo token then you will receive WAERGO back. To
convert to native tokens just use the `unwrap` function on the
WAERGO contract
