;; Define NFT trait interface
(define-trait nft-trait
  ((transfer (uint principal principal) (response bool uint))
   (get-owner (uint) (response principal uint))))

;; Constants for validation
(define-constant max-uint u340282366920938463463374607431768211455)
(define-constant max-price u1000000000000) ;; 1 million STX
(define-constant max-duration u1000000) ;; ~7 months in blocks
(define-constant max-token-id u1000000000)

;; Private helper functions
(define-private (validate-uint (n uint) (max-value uint))
  (begin 
    (asserts! (and (>= n u0) (< n max-value)) ERR-UNAUTHORIZED)
    (ok n)))

(define-private (validate-price (price uint))
  (validate-uint price max-price))

(define-private (validate-duration (duration uint))
  (validate-uint duration max-duration))

(define-private (validate-token-id (token-id uint))
  (validate-uint token-id max-token-id))

(define-private (validate-listing-id (listing-id uint))
  (validate-uint listing-id (var-get next-listing-id)))

;; Principal validation
(define-private (validate-principal (user principal))
  (ok user))

(define-private (validate-nft-contract (contract <nft-trait>))
  (ok (contract-of contract)))

;; Contract Constants
(define-constant contract-owner tx-sender)

;; Error Constants
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-NOT-OWNER (err u101))
(define-constant ERR-NOT-RENTER (err u102))
(define-constant ERR-NFT-NOT-LISTED (err u103))
(define-constant ERR-NFT-RENTED (err u104))
(define-constant ERR-NFT-NOT-RENTED (err u105))
(define-constant ERR-RENTAL-NOT-EXPIRED (err u106))
(define-constant ERR-ALREADY-RENTED (err u107))
(define-constant ERR-CONTRACT-PAUSED (err u108))
(define-constant ERR-NO-DISPUTE (err u109))

(define-data-var admin principal tx-sender)
(define-data-var paused bool false)
(define-data-var next-listing-id uint u1)

;; NFT Listing Struct
(define-map listings
  {listing-id: uint}
  {
    owner: principal,
    contract: principal, ;; NFT contract address
    token-id: uint,     ;; NFT token id
    price: uint,        ;; rental price in microSTX
    duration: uint,     ;; rental duration in blocks
    rented: bool,
    renter: (optional principal),
    rental-expiry: (optional uint),
    collateral: (optional uint),
    dispute: (optional bool)
  }
)

;; ========== ADMIN FUNCTIONS ==========

(define-public (set-admin (new-admin principal))
  (begin
    (let ((current-admin (var-get admin)))
      (asserts! (is-eq tx-sender current-admin) ERR-UNAUTHORIZED))
    (ok (var-get admin))))

(define-public (pause-contract)
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-UNAUTHORIZED)
    (var-set paused true)
    (ok true)
  )
)

(define-public (unpause-contract)
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-UNAUTHORIZED)
    (var-set paused false)
    (ok true)
  )
)

;; ========== LISTING FUNCTIONS ==========

(define-public (list-nft (nft-contract <nft-trait>) (token-id uint) (price uint) (duration uint))
  (begin
    ;; Check contract state
    (asserts! (not (var-get paused)) ERR-CONTRACT-PAUSED)
    
    ;; Validate inputs
    (asserts! (and (>= token-id u0) (< token-id max-token-id)) ERR-UNAUTHORIZED)
    (asserts! (and (>= price u0) (< price max-price)) ERR-UNAUTHORIZED)
    (asserts! (and (>= duration u0) (< duration max-duration)) ERR-UNAUTHORIZED)
    
    (let 
      ((listing-id (var-get next-listing-id))
       (contract-principal (as-contract tx-sender)))
      
      ;; First verify ownership transfer
      (asserts! (is-ok (contract-call? nft-contract transfer token-id tx-sender contract-principal)) ERR-UNAUTHORIZED)
      
      ;; Save listing
      (map-set listings
        {listing-id: listing-id}
        {
          owner: tx-sender,
          contract: (as-contract (contract-of nft-contract)),
          token-id: token-id,
          price: price,
          duration: duration,
          rented: false,
          renter: none,
          rental-expiry: none,
          collateral: none,
          dispute: none
        })
      (var-set next-listing-id (+ listing-id u1))
      (ok listing-id))))

(define-public (update-listing (listing-id uint) (new-price uint) (new-duration uint))
  (begin
    ;; Validate inputs
    (asserts! (and (>= listing-id u0) (< listing-id (var-get next-listing-id))) ERR-UNAUTHORIZED)
    (asserts! (and (>= new-price u0) (< new-price max-price)) ERR-UNAUTHORIZED)
    (asserts! (and (>= new-duration u0) (< new-duration max-duration)) ERR-UNAUTHORIZED)
    
    (let ((listing (map-get? listings {listing-id: listing-id})))
      (match listing listing-data
        (begin
          (asserts! (is-eq (get owner listing-data) tx-sender) ERR-NOT-OWNER)
          (asserts! (not (get rented listing-data)) ERR-NFT-RENTED)
          (asserts! (not (var-get paused)) ERR-CONTRACT-PAUSED)

          (map-set listings {listing-id: listing-id}
            (merge listing-data { price: new-price, duration: new-duration }))
          (ok true))
        ERR-NFT-NOT-LISTED))))

(define-public (delist-nft (listing-id uint))
  (begin
    ;; Validate input
    (asserts! (and (>= listing-id u0) (< listing-id (var-get next-listing-id))) ERR-UNAUTHORIZED)
    
    (let ((listing (map-get? listings {listing-id: listing-id})))
      (match listing
        listing-data (begin
          (asserts! (is-eq (get owner listing-data) tx-sender) ERR-NOT-OWNER)
          (asserts! (not (get rented listing-data)) ERR-NFT-RENTED)
          (asserts! (not (var-get paused)) ERR-CONTRACT-PAUSED)

          (map-delete listings {listing-id: listing-id})
          (ok true))
        ERR-NFT-NOT-LISTED))))

;; ========== RENT FUNCTIONS ==========

(define-public (rent-nft (listing-id uint))
  (begin
    ;; Validate input
    (asserts! (and (>= listing-id u0) (< listing-id (var-get next-listing-id))) ERR-UNAUTHORIZED)
    
    (let ((listing (map-get? listings {listing-id: listing-id})))
      (match listing listing-data
        (begin
          (asserts! (not (get rented listing-data)) ERR-ALREADY-RENTED)
          (asserts! (not (var-get paused)) ERR-CONTRACT-PAUSED)
          ;; Process payment
          (let ((price (get price listing-data)))
            (try! (stx-transfer? price tx-sender (as-contract tx-sender)))
            ;; Update listing to rented
            (map-set listings {listing-id: listing-id}
              (merge listing-data
                {
                  rented: true,
                  renter: (some tx-sender),
                  rental-expiry: (some (+ u1 (get duration listing-data))),
                  collateral: (some price),
                  dispute: none
                }))
            (ok true)))
        ERR-NFT-NOT-LISTED))))

;; Extend rental duration by renter (pays price again)
(define-public (extend-rental (listing-id uint))
  (begin
    ;; Validate input
    (asserts! (and (>= listing-id u0) (< listing-id (var-get next-listing-id))) ERR-UNAUTHORIZED)
    
    (let ((listing (map-get? listings {listing-id: listing-id})))
      (match listing listing-data
        (begin
          (asserts! (get rented listing-data) ERR-NFT-NOT-RENTED)
          (asserts! (is-eq (unwrap-panic (get renter listing-data)) tx-sender) ERR-NOT-RENTER)
          (asserts! (not (var-get paused)) ERR-CONTRACT-PAUSED)
          
          ;; Process payment
          (let ((price (get price listing-data)))
            (try! (stx-transfer? price tx-sender (as-contract tx-sender)))

            ;; Extend rental expiry by duration
            (map-set listings {listing-id: listing-id}
              (merge listing-data
                {
                  rental-expiry: (some (+ (unwrap-panic (get rental-expiry listing-data)) (get duration listing-data))),
                  collateral: (some (+ (unwrap-panic (get collateral listing-data)) price)),
                  dispute: none
                }))

            (ok true)))
        ERR-NFT-NOT-LISTED))))

;; ========== RETURN NFT FUNCTION ==========

(define-public (return-nft (listing-id uint))
  (begin
    ;; Validate input
    (asserts! (and (>= listing-id u0) (< listing-id (var-get next-listing-id))) ERR-UNAUTHORIZED)
    
    (let ((listing (map-get? listings {listing-id: listing-id})))
      (match listing listing-data
        (begin
          (asserts! (get rented listing-data) ERR-NFT-NOT-RENTED)
          (asserts! (is-eq (unwrap-panic (get renter listing-data)) tx-sender) ERR-NOT-RENTER)
          (asserts! (not (var-get paused)) ERR-CONTRACT-PAUSED)
          
          ;; Return collateral to renter
          (let ((collateral-amount (unwrap-panic (get collateral listing-data))))
            (try! (as-contract (stx-transfer? collateral-amount (as-contract tx-sender) tx-sender)))

            ;; Mark NFT as returned
            (map-set listings {listing-id: listing-id}
              (merge listing-data
                {
                  rented: false,
                  renter: none,
                  rental-expiry: none,
                  collateral: none,
                  dispute: none
                }))
            (ok true)))
        ERR-NFT-NOT-LISTED))))

;; ========== CLAIM COLLATERAL (if renter fails to return) ==========

(define-public (claim-collateral (listing-id uint))
  (begin
    ;; Validate input
    (asserts! (and (>= listing-id u0) (< listing-id (var-get next-listing-id))) ERR-UNAUTHORIZED)
    
    (let ((listing (map-get? listings {listing-id: listing-id})))
      (match listing listing-data
        (begin
          (asserts! (get rented listing-data) ERR-NFT-NOT-RENTED)
          (asserts! (is-eq (get owner listing-data) tx-sender) ERR-NOT-OWNER)
          (asserts! (not (var-get paused)) ERR-CONTRACT-PAUSED)
          ;; Only after rental expired
          (asserts! (>= u1 (unwrap-panic (get rental-expiry listing-data))) ERR-RENTAL-NOT-EXPIRED)

          ;; Mark NFT as available and transfer collateral to owner
          (let ((collateral-amount (unwrap-panic (get collateral listing-data))))
            (try! (as-contract (stx-transfer? collateral-amount (as-contract tx-sender) tx-sender)))
            (map-set listings {listing-id: listing-id}
              (merge listing-data
                {
                  rented: false,
                  renter: none,
                  rental-expiry: none,
                  collateral: none,
                  dispute: none
                }))
            (ok true)))
        ERR-NFT-NOT-LISTED))))

;; ========== DISPUTE FUNCTIONS ==========

(define-public (flag-dispute (listing-id uint))
  (begin
    ;; Validate input
    (asserts! (and (>= listing-id u0) (< listing-id (var-get next-listing-id))) ERR-UNAUTHORIZED)
    
    (let ((listing (map-get? listings {listing-id: listing-id})))
      (match listing listing-data
        (begin
          (asserts! (or
                      (is-eq tx-sender (get owner listing-data))
                      (and (get rented listing-data)
                           (is-eq tx-sender (unwrap-panic (get renter listing-data)))))
                    ERR-UNAUTHORIZED)
          (map-set listings {listing-id: listing-id}
            (merge listing-data { dispute: (some true) }))
          (ok true))
        ERR-NFT-NOT-LISTED))))

(define-read-only (get-listing (listing-id uint))
  (map-get? listings {listing-id: listing-id})
)

(define-read-only (is-paused)
  (var-get paused)
)

(define-read-only (get-admin)
  (var-get admin)
)
