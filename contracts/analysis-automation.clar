;; Analysis Automation Contract
;; Automates intelligence analysis processes

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_ANALYSIS_NOT_FOUND (err u401))
(define-constant ERR_INVALID_PARAMETERS (err u402))
(define-constant ERR_ANALYSIS_RUNNING (err u403))

;; Data Variables
(define-data-var next-analysis-id uint u1)

;; Data Maps
(define-map analyses
  { analysis-id: uint }
  {
    name: (string-ascii 100),
    analysis-type: (string-ascii 30),
    parameters: (string-ascii 200),
    status: (string-ascii 20),
    created-by: principal,
    started-at: uint,
    completed-at: (optional uint),
    result-hash: (optional (buff 32))
  }
)

(define-map analysis-configs
  { config-id: uint }
  {
    config-name: (string-ascii 50),
    analysis-type: (string-ascii 30),
    default-parameters: (string-ascii 200),
    is-active: bool,
    created-by: principal
  }
)

(define-data-var next-config-id uint u1)

;; Public Functions

;; Create analysis configuration
(define-public (create-analysis-config (config-name (string-ascii 50)) (analysis-type (string-ascii 30)) (default-parameters (string-ascii 200)))
  (let
    (
      (config-id (var-get next-config-id))
    )

    (map-set analysis-configs
      { config-id: config-id }
      {
        config-name: config-name,
        analysis-type: analysis-type,
        default-parameters: default-parameters,
        is-active: true,
        created-by: tx-sender
      }
    )

    (var-set next-config-id (+ config-id u1))
    (ok config-id)
  )
)

;; Start automated analysis
(define-public (start-analysis (name (string-ascii 100)) (analysis-type (string-ascii 30)) (parameters (string-ascii 200)))
  (let
    (
      (analysis-id (var-get next-analysis-id))
      (caller tx-sender)
    )

    (map-set analyses
      { analysis-id: analysis-id }
      {
        name: name,
        analysis-type: analysis-type,
        parameters: parameters,
        status: "running",
        created-by: caller,
        started-at: block-height,
        completed-at: none,
        result-hash: none
      }
    )

    (var-set next-analysis-id (+ analysis-id u1))
    (ok analysis-id)
  )
)

;; Complete analysis
(define-public (complete-analysis (analysis-id uint) (result-hash (buff 32)))
  (let
    (
      (analysis (unwrap! (map-get? analyses { analysis-id: analysis-id }) ERR_ANALYSIS_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get created-by analysis)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status analysis) "running") ERR_ANALYSIS_RUNNING)

    (map-set analyses
      { analysis-id: analysis-id }
      (merge analysis {
        status: "completed",
        completed-at: (some block-height),
        result-hash: (some result-hash)
      })
    )

    (ok true)
  )
)

;; Cancel analysis
(define-public (cancel-analysis (analysis-id uint))
  (let
    (
      (analysis (unwrap! (map-get? analyses { analysis-id: analysis-id }) ERR_ANALYSIS_NOT_FOUND))
    )
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER) (is-eq tx-sender (get created-by analysis))) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status analysis) "running") ERR_ANALYSIS_RUNNING)

    (map-set analyses
      { analysis-id: analysis-id }
      (merge analysis {
        status: "cancelled",
        completed-at: (some block-height)
      })
    )

    (ok true)
  )
)

;; Update analysis configuration
(define-public (update-analysis-config (config-id uint) (is-active bool))
  (let
    (
      (config (unwrap! (map-get? analysis-configs { config-id: config-id }) ERR_ANALYSIS_NOT_FOUND))
    )
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER) (is-eq tx-sender (get created-by config))) ERR_UNAUTHORIZED)

    (map-set analysis-configs
      { config-id: config-id }
      (merge config { is-active: is-active })
    )

    (ok true)
  )
)

;; Read-only Functions

;; Get analysis details
(define-read-only (get-analysis (analysis-id uint))
  (map-get? analyses { analysis-id: analysis-id })
)

;; Get analysis configuration
(define-read-only (get-analysis-config (config-id uint))
  (map-get? analysis-configs { config-id: config-id })
)

;; Check analysis status
(define-read-only (get-analysis-status (analysis-id uint))
  (match (map-get? analyses { analysis-id: analysis-id })
    analysis (get status analysis)
    "not-found"
  )
)

;; Get analysis results
(define-read-only (get-analysis-results (analysis-id uint))
  (match (map-get? analyses { analysis-id: analysis-id })
    analysis (get result-hash analysis)
    none
  )
)
