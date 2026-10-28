# Prompt cheat sheet

Copy/paste prompts for the live demo, in running order.

**Agent mode: `Ask for approval` for every act.**

---

## 1 · Standards

```text
What rules and skills does this project enforce? 5 bullets. Don't change any files.
```

---

## 2a · Stored proc — inventory

```text
Read legacy/stored_procedures/sp_load_customer_ltv.sql and inventory its business rules. Don't change any files.
```

---

## 2b · Stored proc — migrate

```text
Migrate legacy/stored_procedures/sp_load_customer_ltv.sql to dbt. Build it and run the parity test.
```

---

## 3 · Informatica

```text
Migrate legacy/informatica/m_LOAD_DAILY_SALES_SUMMARY.xml to dbt. Reuse existing models where the rules match. Build and run parity.
```

---

## 4 · Talend

```text
Migrate legacy/talend/J_Product_Returns_Analysis_0.1.item to dbt. Reuse existing models where the rules match. Build and run parity.
```

---

## 5 · Alteryx

```text
Migrate legacy/alteryx/Payment_Reconciliation.yxmd to dbt. Reuse existing models where the rules match, and call out filters that differ. Build and run parity.
```

---

## 6 · Break it on purpose

```text
legacy_parity failed on dim_customer_ltv and audit_helper shows only customer_segment differs. Find the root cause in the legacy proc and fix the model.
```

---

## 7 · Review

```text
Review all models against AGENTS.md and our skills. List violations only.
```
