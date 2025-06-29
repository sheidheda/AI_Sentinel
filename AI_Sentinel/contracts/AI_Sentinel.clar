;; AI Sentinel - Predictive Security Oracle Contract
;; A decentralized prediction market for AI-powered crypto security threats
;; Addressing the $1.77B crypto theft crisis of Q1 2025

;; Contract inspired by the surge in crypto thefts and rise of AI prediction markets
;; Users stake STX to predict security vulnerabilities and earn rewards for accurate predictions

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-unauthorized (err u100))
(define-constant err-invalid-prediction (err u101))
(define-constant err-prediction-exists (err u102))
(define-constant err-prediction-not-found (err u103))
(define-constant err-already-resolved (err u104))
(define-constant err-insufficient-stake (err u105))
(define-constant err-window-closed (err u106))
(define-constant err-already-claimed (err u107))
(define-constant err-invalid-oracle (err u108))

;; Minimum stake: 10 STX (to prevent spam predictions)
(define-constant min-stake u10000000)
;; Oracle registration fee: 100 STX
(define-constant oracle-fee u100000000)
;; Prediction window: ~1 week in blocks
(define-constant prediction-window u1008)

;; Data Variables
(define-data-var prediction-counter uint u0)
(define-data-var total-staked uint u0)
(define-data-var treasury-balance uint u0)
(define-data-var active-oracles uint u0)

;; NFT for verified AI security oracles
(define-non-fungible-token ai-oracle-badge uint)

;; Data Maps
(define-map predictions
    uint ;; prediction-id
    {
        predictor: principal,
        target-protocol: (string-ascii 50),
        vulnerability-type: (string-ascii 30),
        severity-score: uint, ;; 1-100
        predicted-loss: uint, ;; in USD millions
        stake-amount: uint,
        submission-height: uint,
        resolution-height: uint,
        resolved: bool,
        accurate: bool,
        ai-confidence: uint ;; 0-100 AI confidence score
    }
)

(define-map oracle-registry
    principal
    {
        reputation-score: uint,
        total-predictions: uint,
        accurate-predictions: uint,
        registration-height: uint,
        is-active: bool
    }
)

(define-map prediction-outcomes
    uint ;; prediction-id
    {
        actual-loss: uint,
        incident-confirmed: bool,
        resolution-oracle: principal,
        verification-hash: (buff 32)
    }
)

(define-map user-rewards
    principal
    {
        total-earned: uint,
        unclaimed: uint,
        prediction-count: uint,
        accuracy-rate: uint
    }
)

;; Protocol risk scores (updated by oracles)
(define-map protocol-risk-scores
    (string-ascii 50)
    {
        current-risk: uint,
        last-updated: uint,
        incidents-count: uint,
        total-losses: uint
    }
)

;; Read-only functions
(define-read-only (get-prediction (prediction-id uint))
    (map-get? predictions prediction-id)
)

(define-read-only (get-oracle-stats (oracle principal))
    (map-get? oracle-registry oracle)
)

(define-read-only (get-protocol-risk (protocol (string-ascii 50)))
    (default-to 
        {current-risk: u0, last-updated: u0, incidents-count: u0, total-losses: u0}
        (map-get? protocol-risk-scores protocol)
    )
)

(define-read-only (calculate-reward (stake uint) (severity uint) (accuracy-bonus uint))
    (let (
        (base-reward (/ (* stake severity) u100))
        (bonus-multiplier (+ u100 accuracy-bonus))
    )
        (/ (* base-reward bonus-multiplier) u100)
    )
)

(define-read-only (is-prediction-window-open (submission-height uint))
    (< (- stacks-block-height submission-height) prediction-window)
)

;; Utility functions (moved up to be available for use)
(define-private (abs-diff (a uint) (b uint))
    (if (> a b) (- a b) (- b a))
)

(define-private (min-uint (a uint) (b uint))
    (if (< a b) a b)
)

(define-private (max-uint (a uint) (b uint))
    (if (> a b) a b)
)

(define-private (calculate-reputation (current uint) (success bool))
    (if success
        (min-uint u100 (+ current u2))
        (max-uint u0 (- current u5))
    )
)

;; Public functions

;; Register as an AI security oracle
(define-public (register-oracle)
    (let (
        (oracle-id (var-get active-oracles))
    )
        (asserts! (is-none (map-get? oracle-registry tx-sender)) err-prediction-exists)
        (try! (stx-transfer? oracle-fee tx-sender (as-contract tx-sender)))
        
        (map-set oracle-registry tx-sender {
            reputation-score: u50,
            total-predictions: u0,
            accurate-predictions: u0,
            registration-height: stacks-block-height,
            is-active: true
        })
        
        (try! (nft-mint? ai-oracle-badge oracle-id tx-sender))
        (var-set active-oracles (+ oracle-id u1))
        (var-set treasury-balance (+ (var-get treasury-balance) oracle-fee))
        (ok oracle-id)
    )
)

;; Submit a security prediction
(define-public (submit-prediction 
    (target-protocol (string-ascii 50))
    (vulnerability-type (string-ascii 30))
    (severity-score uint)
    (predicted-loss uint)
    (stake-amount uint)
    (ai-confidence uint))
    (let (
        (prediction-id (+ (var-get prediction-counter) u1))
        (oracle-data (unwrap! (map-get? oracle-registry tx-sender) err-invalid-oracle))
    )
        (asserts! (get is-active oracle-data) err-unauthorized)
        (asserts! (>= stake-amount min-stake) err-insufficient-stake)
        (asserts! (<= severity-score u100) err-invalid-prediction)
        (asserts! (<= ai-confidence u100) err-invalid-prediction)
        
        (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))
        
        (map-set predictions prediction-id {
            predictor: tx-sender,
            target-protocol: target-protocol,
            vulnerability-type: vulnerability-type,
            severity-score: severity-score,
            predicted-loss: predicted-loss,
            stake-amount: stake-amount,
            submission-height: stacks-block-height,
            resolution-height: (+ stacks-block-height prediction-window),
            resolved: false,
            accurate: false,
            ai-confidence: ai-confidence
        })
        
        (var-set prediction-counter prediction-id)
        (var-set total-staked (+ (var-get total-staked) stake-amount))
        
        ;; Update protocol risk score
        (let ((current-risk-data (get-protocol-risk target-protocol)))
            (map-set protocol-risk-scores target-protocol {
                current-risk: (/ (+ (* (get current-risk current-risk-data) u3) severity-score) u4),
                last-updated: stacks-block-height,
                incidents-count: (get incidents-count current-risk-data),
                total-losses: (get total-losses current-risk-data)
            })
        )
        
        (ok prediction-id)
    )
)

;; Resolve a prediction (called by verified oracles)
(define-public (resolve-prediction 
    (prediction-id uint)
    (incident-confirmed bool)
    (actual-loss uint)
    (verification-hash (buff 32)))
    (let (
        (prediction (unwrap! (map-get? predictions prediction-id) err-prediction-not-found))
        (oracle-data (unwrap! (map-get? oracle-registry tx-sender) err-invalid-oracle))
    )
        (asserts! (get is-active oracle-data) err-unauthorized)
        (asserts! (not (get resolved prediction)) err-already-resolved)
        (asserts! (>= stacks-block-height (get resolution-height prediction)) err-window-closed)
        
        ;; Calculate accuracy
        (let (
            (loss-accuracy (if incident-confirmed
                (if (< (/ (* (abs-diff actual-loss (get predicted-loss prediction)) u100) 
                        (get predicted-loss prediction))
                     u20)
                    true
                    false)
                false))
            (is-accurate (and incident-confirmed loss-accuracy))
        )
            ;; Update prediction
            (map-set predictions prediction-id (merge prediction {
                resolved: true,
                accurate: is-accurate
            }))
            
            ;; Record outcome
            (map-set prediction-outcomes prediction-id {
                actual-loss: actual-loss,
                incident-confirmed: incident-confirmed,
                resolution-oracle: tx-sender,
                verification-hash: verification-hash
            })
            
            ;; Update oracle stats
            (map-set oracle-registry tx-sender (merge oracle-data {
                total-predictions: (+ (get total-predictions oracle-data) u1),
                accurate-predictions: (if is-accurate 
                    (+ (get accurate-predictions oracle-data) u1)
                    (get accurate-predictions oracle-data)),
                reputation-score: (calculate-reputation 
                    (get reputation-score oracle-data)
                    is-accurate)
            }))
            
            ;; Update protocol risk if incident confirmed
            (if incident-confirmed
                (let ((risk-data (get-protocol-risk (get target-protocol prediction))))
                    (map-set protocol-risk-scores (get target-protocol prediction) {
                        current-risk: (min-uint u100 (+ (get current-risk risk-data) u10)),
                        last-updated: stacks-block-height,
                        incidents-count: (+ (get incidents-count risk-data) u1),
                        total-losses: (+ (get total-losses risk-data) actual-loss)
                    })
                )
                true
            )
            
            ;; Calculate and assign rewards
            (if is-accurate
                (let (
                    (reward (calculate-reward 
                        (get stake-amount prediction)
                        (get severity-score prediction)
                        (get ai-confidence prediction)))
                    (predictor-rewards (default-to 
                        {total-earned: u0, unclaimed: u0, prediction-count: u0, accuracy-rate: u0}
                        (map-get? user-rewards (get predictor prediction))))
                )
                    (map-set user-rewards (get predictor prediction) {
                        total-earned: (+ (get total-earned predictor-rewards) reward),
                        unclaimed: (+ (get unclaimed predictor-rewards) reward),
                        prediction-count: (+ (get prediction-count predictor-rewards) u1),
                        accuracy-rate: (/ (* (+ (get accuracy-rate predictor-rewards) u100) u100) 
                                         (+ (get prediction-count predictor-rewards) u1))
                    })
                )
                true
            )
            
            (ok true)
        )
    )
)

;; Claim rewards
(define-public (claim-rewards)
    (let (
        (rewards (unwrap! (map-get? user-rewards tx-sender) err-prediction-not-found))
        (claimable (get unclaimed rewards))
    )
        (asserts! (> claimable u0) err-already-claimed)
        
        (try! (as-contract (stx-transfer? claimable tx-sender tx-sender)))
        
        (map-set user-rewards tx-sender (merge rewards {
            unclaimed: u0
        }))
        
        (ok claimable)
    )
)

;; Emergency protocol pause (for high-risk protocols)
(define-public (flag-critical-risk (protocol (string-ascii 50)))
    (let (
        (oracle-data (unwrap! (map-get? oracle-registry tx-sender) err-invalid-oracle))
        (risk-data (get-protocol-risk protocol))
    )
        (asserts! (get is-active oracle-data) err-unauthorized)
        (asserts! (>= (get reputation-score oracle-data) u80) err-unauthorized)
        
        (map-set protocol-risk-scores protocol (merge risk-data {
            current-risk: u100,
            last-updated: stacks-block-height
        }))
        
        (ok true)
    )
)

;; Contract initialization
(begin
    (var-set prediction-counter u0)
    (var-set total-staked u0)
    (var-set treasury-balance u0)
    (var-set active-oracles u0)
)