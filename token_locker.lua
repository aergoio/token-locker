--[[

TokenLocker v1

To use:

  Transfer tokens to this contract, and specify the period to
  lock them as an argument in the transfer function.
  The period is in seconds.

  Example:

  contract.call(token, "transfer", token_locker, amount, period)

]]

state.var {
  locks = state.map(),
  per_token = state.map()
}

function tokensReceived(operator, from, amount, period)

  -- the contract calling this function
  local token = system.getSender()

  -- who sent the tokens
  local account = from

  -- convert the amount to bignumber
  --amount = bignum.number(amount)
  assert(bignum.compare(amount, 0) > 0, "the amount must be positive")

  -- convert the period to number
  if type(period) ~= 'number' then
    period = tonumber(period)
  end

  local lock = {
    amount = amount,
    token = token,
    expiration_time = system.getTimestamp() + period
  }

  -- check if this account already have any locked tokens
  local account_locks = locks[account]
  if account_locks == nil then
    account_locks = {}
  end

  -- add the new lock to the list (use an array of tables)
  table.insert(account_locks, lock)

  -- save it
  locks[account] = account_locks

  -- update the total locked amount for this token
  per_token[token] = (per_token[token] or bignum.number(0)) + amount

end

function list_locked_tokens(account)
  local account_locks = locks[account]
  return json.encode(account_locks)
end

function get_total_locked(token)
  return bignum.tostring(per_token[token] or bignum.number(0))
end

function withdraw(index)

  -- transaction signer or contract
  local account = system.getSender()

  -- get the locked tokens from this account
  local account_locks = locks[account]
  assert(account_locks ~= nil, "no locked tokens for this account")

  -- get the locked tokens at the given index
  if index == nil then
    index = 1
  end
  local lock = account_locks[index]
  assert(lock ~= nil, "no locked tokens at this index")

  -- check if the tokens are unlocked
  assert(lock["expiration_time"] <= system.getTimestamp(), "these tokens are locked until " .. lock["expiration_time"])

  -- update the state BEFORE any external call to avoid reentrancy attack

  -- are there more than 1 lock for this account?
  if #account_locks > 1 then
    -- remove the lock from the list
    table.remove(account_locks, index)
    -- save the updated list
    locks[account] = account_locks
  else
    -- no more locks for this account
    locks:delete(account)
  end

  -- update the total locked amount for this token
  per_token[token] = per_token[token] - lock["amount"]

  -- transfer the tokens
  contract.call(lock["token"], "transfer", lock["account"], lock["amount"])

end

abi.register(tokensReceived, withdraw)
abi.register_view(list_locked_tokens, get_total_locked)

--[[

Available Lua modules:
  string  math  table  bit

Available Aergo modules:
  system  contract  db  crypto  bignum  json

]]
