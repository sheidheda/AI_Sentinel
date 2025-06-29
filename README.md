# AI Sentinel – Predictive Security Oracle Contract

A decentralized AI-powered prediction market to mitigate cryptocurrency security threats. Inspired by the $1.77B loss in crypto thefts in Q1 2025, this smart contract enables AI oracles to predict vulnerabilities in blockchain protocols and earn rewards for accurate forecasts.

## 🔒 Purpose

The AI Sentinel contract brings together AI prediction markets and crypto security intelligence. By staking and validating predictions, users and registered oracles contribute to a proactive defense against blockchain threats.

## 🌐 Core Features

- **Decentralized Predictions**: Stake STX to predict vulnerabilities, attack types, or potential losses.
- **AI Integration**: Submit AI-driven confidence scores for enhanced predictive reliability.
- **Oracle Network**: Verified AI oracles register and maintain reputation to resolve predictions.
- **Risk Intelligence Feed**: Dynamic protocol risk scores updated based on predictions and incidents.
- **Gamified Reputation**: Reputation and reward system to incentivize accurate security forecasting.


## 📦 Smart Contract Components

### Constants

| Constant             | Value       | Description                                  |
|----------------------|-------------|----------------------------------------------|
| `min-stake`          | 10 STX      | Minimum stake to submit a prediction         |
| `oracle-fee`         | 100 STX     | Fee to register as an AI oracle              |
| `prediction-window`  | 1008 blocks | Time until predictions can be resolved       |


## 📊 Data Structures

### NFTs
- `ai-oracle-badge`: Issued to verified oracles for reputation-based security verification.

### Maps

- `predictions`: All submitted predictions with severity, stake, AI confidence, and timing.
- `oracle-registry`: Oracle status, reputation, and registration details.
- `prediction-outcomes`: Result data after resolution (confirmed or not, actual loss).
- `protocol-risk-scores`: Risk metadata (risk level, incidents, losses) per protocol.
- `user-rewards`: Earned and unclaimed rewards for predictors.


## 🔧 Key Functions

### Oracle Registration

```clojure
(register-oracle)
````

Register a new oracle (must pay 100 STX). Mints `ai-oracle-badge` and initializes reputation score.

---

### Prediction Submission

```clojure
(submit-prediction target-protocol vulnerability-type severity-score predicted-loss stake-amount ai-confidence)
```

Submit a prediction. Requires:

* Stake ≥ 10 STX
* Severity score and confidence (0–100)


### Prediction Resolution

```clojure
(resolve-prediction prediction-id incident-confirmed actual-loss verification-hash)
```

Called by oracles after the prediction window closes. Determines if the prediction was accurate and updates:

* Oracle reputation
* Protocol risk
* User rewards


### Claim Rewards

```clojure
(claim-rewards)
```

Allows predictors to claim unclaimed rewards from accurate predictions.


### Emergency Risk Flagging

```clojure
(flag-critical-risk protocol)
```

Used by oracles with ≥80 reputation to immediately flag a protocol as high-risk (`current-risk = 100`).


## 🎯 Accuracy Logic

A prediction is **accurate** if:

* An incident occurs **(confirmed = true)**
* Predicted loss is within ±20% of the actual loss


## 🏆 Reward Mechanics

Reward is calculated as:

```
reward = (stake * severity / 100) * (1 + ai-confidence / 100)
```

Higher severity and AI confidence yield better rewards.


## 📈 Reputation System

| Event               | Effect              |
| ------------------- | ------------------- |
| Accurate Prediction | +2 points (max 100) |
| Missed Prediction   | –5 points (min 0)   |


## 🛡️ Access Control

| Action                 | Required Role           |
| ---------------------- | ----------------------- |
| Submit Prediction      | Registered Oracle       |
| Resolve Prediction     | Registered Oracle       |
| Flag Critical Protocol | Oracle (Reputation ≥80) |


## 🧾 License

MIT License. Open for contribution and audit.

## 🤝 Contributing

Security researchers, AI engineers, and smart contract developers are welcome to enhance threat models, integrate off-chain data feeds, or propose oracle governance structures.
