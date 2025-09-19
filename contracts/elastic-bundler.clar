;; =========================================================
;; ERC4626 ELASTIC BUNDLER CONTRACT
;; =========================================================
;; A flexible, dynamic vault for managing ERC4626-compatible
;; tokenized investment strategies with elastic supply mechanisms.
;; =========================================================

;; =========================================================
;; Error Constants
;; =========================================================
(define-constant ERR-INSUFFICIENT-BALANCE u100)
(define-constant ERR-INVALID-AMOUNT u101)
(define-constant ERR-NOT-AUTHORIZED u102)
(define-constant ERR-DEPOSIT-FAILED u103)
(define-constant ERR-WITHDRAWAL-FAILED u104)

;; =========================================================
;; Data Maps and Variables
;; =========================================================
;; Vault state tracking total assets and shares
(define-data-var total-assets uint u0)
(define-data-var total-shares uint u0)

;; User balance tracking
(define-map user-balances
  { account: principal }
  { shares: uint, deposited-assets: uint }
)

;; Allowance tracking for flexible delegation
(define-map allowances
  { owner: principal, spender: principal }
  { amount: uint }
)

;; =========================================================
;; Private Functions
;; =========================================================
;; Calculate shares to mint based on deposit amount
(define-private (calculate-shares-for-deposit (assets uint))
  (let ((total-supply (var-get total-shares))
        (total-assets-before (var-get total-assets)))
    (if (or (is-eq total-assets-before u0) (is-eq total-supply u0))
      assets
      (/ (* assets total-supply) total-assets-before)
    )
  )
)

;; Calculate assets to withdraw based on share amount
(define-private (calculate-assets-for-withdrawal (shares uint))
  (let ((total-supply (var-get total-shares))
        (total-assets-before (var-get total-assets)))
    (if (is-eq total-supply u0)
      u0
      (/ (* shares total-assets-before) total-supply)
    )
  )
)

;; =========================================================
;; Read-Only Functions
;; =========================================================
;; Get user's share balance
(define-read-only (balance-of (account principal))
  (default-to { shares: u0, deposited-assets: u0 }
    (map-get? user-balances { account: account })
  )
)

;; Get current total assets in the vault
(define-read-only (total-assets-under-management)
  (var-get total-assets)
)

;; Get current total shares issued
(define-read-only (total-supply)
  (var-get total-shares)
)

;; =========================================================
;; Public Functions
;; =========================================================
;; Deposit assets into the vault
(define-public (deposit (assets uint))
  (let ((sender tx-sender)
        (shares-to-mint (calculate-shares-for-deposit assets)))
    (asserts! (> assets u0) (err ERR-INVALID-AMOUNT))
    
    ;; Transfer assets to vault (simplified, would interact with token contract)
    ;; (try! (transfer-from-user sender assets))
    
    ;; Update user balance
    (map-set user-balances 
      { account: sender }
      { 
        shares: (+ (get shares (balance-of sender)) shares-to-mint),
        deposited-assets: (+ (get deposited-assets (balance-of sender)) assets)
      }
    )
    
    ;; Update total assets and shares
    (var-set total-assets (+ (var-get total-assets) assets))
    (var-set total-shares (+ (var-get total-shares) shares-to-mint))
    
    (ok shares-to-mint)
  )
)

;; Withdraw assets from the vault
(define-public (withdraw (shares uint))
  (let ((sender tx-sender)
        (user-balance (balance-of sender))
        (assets-to-withdraw (calculate-assets-for-withdrawal shares)))
    (asserts! (>= (get shares user-balance) shares) (err ERR-INSUFFICIENT-BALANCE))
    (asserts! (> shares u0) (err ERR-INVALID-AMOUNT))
    
    ;; Update user balance
    (map-set user-balances 
      { account: sender }
      { 
        shares: (- (get shares user-balance) shares),
        deposited-assets: (- (get deposited-assets user-balance) assets-to-withdraw)
      }
    )
    
    ;; Update total assets and shares
    (var-set total-assets (- (var-get total-assets) assets-to-withdraw))
    (var-set total-shares (- (var-get total-shares) shares))
    
    ;; Transfer assets back to user (simplified)
    ;; (try! (transfer-to-user sender assets-to-withdraw))
    
    (ok assets-to-withdraw)
  )
)

;; Approve allowance for another address to spend shares
(define-public (approve (spender principal) (amount uint))
  (map-set allowances 
    { owner: tx-sender, spender: spender }
    { amount: amount }
  )
  (ok true)
)

;; Transfer shares to another account
(define-public (transfer (recipient principal) (amount uint))
  (let ((sender tx-sender)
        (sender-balance (balance-of sender)))
    (asserts! (>= (get shares sender-balance) amount) (err ERR-INSUFFICIENT-BALANCE))
    
    ;; Update sender's balance
    (map-set user-balances 
      { account: sender }
      { 
        shares: (- (get shares sender-balance) amount),
        deposited-assets: (get deposited-assets sender-balance)
      }
    )
    
    ;; Update recipient's balance
    (map-set user-balances 
      { account: recipient }
      { 
        shares: (+ (get shares (balance-of recipient)) amount),
        deposited-assets: (get deposited-assets (balance-of recipient))
      }
    )
    
    (ok true)
  )
)