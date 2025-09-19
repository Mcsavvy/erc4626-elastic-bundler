import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.0.3/index.ts';
import { assertEquals } from 'https://deno.land/std@0.170.0/testing/asserts.ts';

Clarinet.test({
  name: "Elastic Bundler: Deposit and Withdrawal Mechanics",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const user1 = accounts.get('wallet_1')!;

    let block = chain.mineBlock([
      Tx.contractCall('elastic-bundler', 'deposit', 
        [types.uint(1000)], 
        user1.address
      )
    ]);

    // Assert successful deposit
    assertEquals(block.height, 2);
    block.receipts[0].result.expectOk();

    // Check total assets and user balance
    let totalAssets = chain.callReadOnlyFn('elastic-bundler', 'total-assets-under-management', [], deployer.address);
    totalAssets.result.expectUint(1000);

    let userBalance = chain.callReadOnlyFn('elastic-bundler', 'balance-of', [types.principal(user1.address)], deployer.address);
    userBalance.result.expectTuple({
      'shares': types.uint(1000),
      'deposited-assets': types.uint(1000)
    });
  }
});

Clarinet.test({
  name: "Elastic Bundler: Withdrawal Mechanics",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const user1 = accounts.get('wallet_1')!;

    let block = chain.mineBlock([
      Tx.contractCall('elastic-bundler', 'deposit', 
        [types.uint(2000)], 
        user1.address
      ),
      Tx.contractCall('elastic-bundler', 'withdraw', 
        [types.uint(1000)], 
        user1.address
      )
    ]);

    // Assert successful withdrawal
    assertEquals(block.height, 2);
    block.receipts[1].result.expectOk();

    let totalAssets = chain.callReadOnlyFn('elastic-bundler', 'total-assets-under-management', [], deployer.address);
    totalAssets.result.expectUint(1000);

    let userBalance = chain.callReadOnlyFn('elastic-bundler', 'balance-of', [types.principal(user1.address)], deployer.address);
    userBalance.result.expectTuple({
      'shares': types.uint(1000),
      'deposited-assets': types.uint(1000)
    });
  }
});