"""
Summit Outfitters — fake data generator for the dbt Wizard legacy-migration workshop.

Produces:
  seeds/raw/*.csv                 -> the raw source data (dbt seeds, loaded to <schema>_raw)
  seeds/legacy_targets/*.csv      -> what the 4 legacy tools "produced" (golden parity data)

The legacy outputs are computed here in Python as the single source of truth for the
business rules encoded in the four legacy artifacts (stored proc, Informatica, Talend,
Alteryx). All money math uses Decimal with ROUND_HALF_UP (== Snowflake ROUND on NUMBER).

Run:  python generate_data.py <path-to-Wizard-Workshop-Refactor>
"""
import csv
import random
import sys
from collections import defaultdict
from datetime import date, timedelta
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path

AS_OF_DATE = date(2026, 9, 30)
START_DATE = date(2025, 1, 1)
ETL_LOAD_TS = {
    "ltv": "2026-10-01 02:15:07",
    "sales": "2026-10-01 03:02:44",
    "returns": "2026-10-01 03:40:19",
    "recon": "2026-10-01 04:05:51",
}

D = Decimal
C2 = D("0.01")
C4 = D("0.0001")
C6 = D("0.000001")


def r2(x):
    return D(x).quantize(C2, rounding=ROUND_HALF_UP)


def r4(x):
    return D(x).quantize(C4, rounding=ROUND_HALF_UP)


AMBIGUOUS = []


def safe_div_round(num, den, places, label):
    """Round num/den; flag values whose rounding is engine-sensitive (6dp intermediate, exact ties)."""
    q = C2 if places == 2 else C4
    exact = (D(num) / D(den)).quantize(q, rounding=ROUND_HALF_UP)
    six = (D(num) / D(den)).quantize(C6, rounding=ROUND_HALF_UP).quantize(q, rounding=ROUND_HALF_UP)
    shifted = (D(num) / D(den)) * (D(10) ** places)
    is_tie = (shifted - shifted.to_integral_value(rounding="ROUND_FLOOR")) == D("0.5")
    if exact != six or (is_tie and places == 4):
        # 4dp ratios: reject exact half-way values too (engine-sensitive). 2dp ties (e.g. AOV
        # = x.xx5) are kept: Snowflake NUMBER division is exact and ROUND is half-up.
        AMBIGUOUS.append((label, num, den, exact, six))
    return exact


# ----------------------------------------------------------------------------------
# Raw data
# ----------------------------------------------------------------------------------
FIRST = ["Avery", "Jordan", "Riley", "Casey", "Morgan", "Taylor", "Quinn", "Harper", "Rowan", "Emerson",
         "Parker", "Sage", "Hayden", "Reese", "Logan", "Dakota", "Skyler", "Cameron", "Finley", "Blake",
         "Elena", "Marcus", "Priya", "Diego", "Mei", "Omar", "Ingrid", "Kofi", "Lena", "Tomas"]
LAST = ["Alder", "Brooks", "Castillo", "Dunn", "Ellison", "Fischer", "Garza", "Holt", "Iverson", "Jensen",
        "Kaur", "Lindqvist", "Mendez", "Nakamura", "Okafor", "Petrov", "Quintero", "Ramsey", "Sato", "Thorne",
        "Ueda", "Vance", "Whitaker", "Xu", "Yates", "Zielinski"]
STATES = ["CO", "UT", "WA", "OR", "CA", "MT", "ID", "WY", "NM", "AZ", "MN", "VT", "NY", "TX", "IN"]
DOMAINS = ["gmail.com", "outlook.com", "yahoo.com", "icloud.com", "proton.me"]

PRODUCTS = [
    # category, subcategory, name, list_price, unit_cost
    ("Footwear", "Hiking Boots", "Ridgeline Mid GTX Boot", "189.00", "82.40"),
    ("Footwear", "Hiking Boots", "Summit Pro Leather Boot", "245.00", "108.75"),
    ("Footwear", "Trail Runners", "Scree Dash Trail Runner", "139.00", "57.10"),
    ("Footwear", "Trail Runners", "Talus Lite Runner", "119.95", "49.30"),
    ("Footwear", "Sandals", "Canyon Strap Sandal", "64.50", "22.15"),
    ("Footwear", "Camp Shoes", "Basecamp Slip-On", "54.00", "19.80"),
    ("Apparel", "Jackets", "Stormfront 3L Shell", "329.00", "141.60"),
    ("Apparel", "Jackets", "Alpenglow Down Hoodie", "279.00", "118.20"),
    ("Apparel", "Fleece", "Switchback Grid Fleece", "99.00", "36.45"),
    ("Apparel", "Base Layers", "Merino 200 Crew", "84.95", "31.70"),
    ("Apparel", "Base Layers", "Merino 150 Tee", "64.95", "23.85"),
    ("Apparel", "Pants", "Traverse Softshell Pant", "129.00", "47.95"),
    ("Apparel", "Pants", "Boulder Field Short", "59.00", "20.40"),
    ("Apparel", "Headwear", "Trailhead Trucker Cap", "29.95", "8.60"),
    ("Camping", "Tents", "Highline 2P Tent", "449.00", "196.30"),
    ("Camping", "Tents", "Meadow 4P Family Tent", "389.00", "171.25"),
    ("Camping", "Sleeping Bags", "Ember 20F Down Bag", "299.00", "127.80"),
    ("Camping", "Sleeping Bags", "Drift 40F Synthetic Bag", "149.00", "58.35"),
    ("Camping", "Sleeping Pads", "Loft Air Pad", "169.00", "66.90"),
    ("Camping", "Cooking", "Firebox Stove Kit", "119.00", "44.70"),
    ("Camping", "Cooking", "Titanium Pot 900ml", "54.95", "18.25"),
    ("Climbing", "Harnesses", "Crux Sport Harness", "74.95", "28.40"),
    ("Climbing", "Ropes", "Dyna 9.8mm 60m Rope", "219.00", "94.10"),
    ("Climbing", "Carabiners", "Lockdown Screwgate (4pk)", "49.95", "16.80"),
    ("Climbing", "Shoes", "Edge Pro Climbing Shoe", "164.00", "65.25"),
    ("Climbing", "Helmets", "Halo Climbing Helmet", "89.00", "33.90"),
    ("Water Sports", "Paddles", "Current Carbon Paddle", "199.00", "79.40"),
    ("Water Sports", "PFDs", "Eddy Touring PFD", "129.95", "48.75"),
    ("Water Sports", "Dry Bags", "Seal Tight 20L Dry Bag", "34.95", "10.20"),
    ("Water Sports", "Dry Bags", "Seal Tight 35L Dry Bag", "44.95", "13.65"),
    ("Accessories", "Packs", "Cairn 28L Daypack", "139.00", "52.80"),
    ("Accessories", "Packs", "Longtrail 65L Pack", "289.00", "119.35"),
    ("Accessories", "Hydration", "Flow 2L Reservoir", "39.95", "12.45"),
    ("Accessories", "Lighting", "Lumen 400 Headlamp", "49.95", "17.10"),
    ("Accessories", "Navigation", "Bearing Baseplate Compass", "34.50", "11.25"),
    ("Accessories", "Poles", "Ascent Carbon Trekking Poles", "159.00", "61.80"),
    ("Accessories", "Bottles", "Insulated Bottle 32oz", "36.00", "11.40"),
    ("Accessories", "Tools", "Ridge Multi-Tool", "69.00", "24.30"),
    ("Accessories", "First Aid", "Backcountry First Aid Kit", "44.00", "15.95"),
    ("Accessories", "Packs", "Hip Pack 4L", "49.00", "16.75"),
]

# order_status raw values -> normalized
STATUS_RAW = {
    "COMPLETED": ["completed", "Completed", "COMPLETED", " completed"],
    "SHIPPED": ["shipped", "Shipped", "SHIPPED "],
    "RETURNED": ["returned", "Returned"],
    "CANCELLED": ["cancelled", "Cancelled", "CANCELLED"],
    "PENDING": ["pending", "Pending"],
}
CHANNEL_RAW = ["web", "Web", "WEB ", "app", "APP", "store", "Store", "marketplace", "Marketplace", "phone", ""]
REASONS_RAW = ["DMG", "dmg", " DMG", "SIZE", "size ", "Size", "DESC", "desc", "MIND", "mind", "LATE", "late"]
VALID_STATUSES = {"COMPLETED", "SHIPPED", "RETURNED"}


def month_start(d):
    return date(d.year, d.month, 1)


def norm(s):
    return (s or "").strip().upper()


def build_raw(rng):
    # ---------------- customers ----------------
    customers = []
    n_customers = 220
    test_ids = set(rng.sample(range(1, n_customers + 1), 6))
    # customer archetypes for segment coverage
    for cid in range(1, n_customers + 1):
        fn, ln = rng.choice(FIRST), rng.choice(LAST)
        email = f"{fn}.{ln}{cid}@{rng.choice(DOMAINS)}".lower()
        r = rng.random()
        if r < 0.15:
            email = email.upper()
        elif r < 0.25:
            email = f"  {email} "
        tier = rng.choices(["Bronze", "Silver", "Gold", "Platinum", None],
                           [35, 28, 18, 7, 12])[0]
        if tier and rng.random() < 0.25:
            tier = rng.choice([tier.upper(), tier.lower(), f" {tier}"])
        state = rng.choice(STATES)
        if rng.random() < 0.2:
            state = state.lower()
        if cid in test_ids:
            is_test = rng.choice(["Y", "y", "Y "])
            email = f"qa.user{cid}@summitoutfitters-test.com"
        else:
            is_test = rng.choices(["N", "n", "", None], [80, 5, 8, 7])[0]
        signup = START_DATE - timedelta(days=rng.randint(0, 900)) + timedelta(days=rng.randint(0, 500))
        customers.append(dict(customer_id=cid, first_name=fn, last_name=ln, email=email, state=state,
                              signup_date=signup.isoformat(), loyalty_tier=tier or "",
                              is_test_account=is_test if is_test is not None else ""))

    # ---------------- products ----------------
    products = []
    for i, (cat, sub, name, lp, uc) in enumerate(PRODUCTS, start=1):
        pid = 100 + i
        products.append(dict(product_id=pid, sku=f"SO-{cat[:3].upper()}-{pid:04d}", product_name=name,
                             category=cat, subcategory=sub, list_price=lp, unit_cost=uc,
                             is_active="false" if i in (6, 21, 38) else "true"))
    product_ids = [p["product_id"] for p in products]
    price = {p["product_id"]: D(p["list_price"]) for p in products}

    # ---------------- fx rates ----------------
    fx = []
    m = START_DATE
    cad, eur = D("0.7350"), D("1.0850")
    while m <= AS_OF_DATE:
        cad = (cad * D(str(1 + rng.uniform(-0.012, 0.012)))).quantize(C6)
        eur = (eur * D(str(1 + rng.uniform(-0.012, 0.012)))).quantize(C6)
        fx.append(dict(currency_code="CAD", rate_month=m.isoformat(), usd_per_unit=str(cad)))
        fx.append(dict(currency_code="EUR", rate_month=m.isoformat(), usd_per_unit=str(eur)))
        m = date(m.year + (m.month // 12), m.month % 12 + 1, 1)

    # ---------------- orders + lines ----------------
    orders, lines = [], []
    oid, lid = 10000, 500000
    span = (AS_OF_DATE - START_DATE).days
    no_order_customers = set(rng.sample([c for c in range(1, n_customers + 1) if c not in test_ids], 18))
    churned = set(rng.sample([c for c in range(1, n_customers + 1) if c not in no_order_customers], 30))
    whales = set(rng.sample([c for c in range(1, n_customers + 1)
                             if c not in no_order_customers and c not in churned], 25))
    for c in customers:
        cid = c["customer_id"]
        if cid in no_order_customers:
            continue
        n = rng.randint(1, 4) if cid not in whales else rng.randint(8, 16)
        if cid in test_ids:
            n = rng.randint(2, 5)
        for _ in range(n):
            oid += 1
            if cid in churned:
                od = START_DATE + timedelta(days=rng.randint(0, 420))  # ends ~Feb 2026
            else:
                od = START_DATE + timedelta(days=rng.randint(0, span))
            st = rng.choices(list(STATUS_RAW), [70, 12, 6, 7, 5])[0]
            if od > AS_OF_DATE - timedelta(days=10) and st in ("COMPLETED",):
                st = rng.choice(["SHIPPED", "PENDING"])
            cur = rng.choices(["USD", "CAD", "EUR"], [75, 15, 10])[0]
            ship = rng.choice(["0.00", "0.00", "5.95", "7.95", "9.95", "14.50", "19.99"])
            orders.append(dict(order_id=oid, customer_id=cid, order_date=od.isoformat(),
                               status=rng.choice(STATUS_RAW[st]), channel=rng.choice(CHANNEL_RAW),
                               currency_code=cur if rng.random() > 0.05 else cur.lower(),
                               shipping_cost=ship,
                               promo_code=rng.choice(["", "", "", "SPRING10", "TRAIL15", "WELCOME5", "STAFF20"])))
            for _ in range(rng.choices([1, 2, 3, 4], [40, 32, 18, 10])[0]):
                lid += 1
                pid = rng.choice(product_ids)
                qty = rng.choices([1, 2, 3, 4, 6], [62, 22, 9, 5, 2])[0]
                up = price[pid]
                if rng.random() < 0.1:
                    up = r2(up * D("0.85"))  # clearance price
                disc = rng.choices(["0", "0.05", "0.10", "0.125", "0.15", "0.20"], [55, 12, 13, 5, 10, 5])[0]
                lines.append(dict(order_line_id=lid, order_id=oid, product_id=pid, quantity=qty,
                                  unit_price=str(up), discount_pct=disc))
    # edge cases: zero-qty lines, and lines for a deleted product (999)
    for ln in rng.sample(lines, 6):
        ln["quantity"] = 0
    for ln in rng.sample(lines, 4):
        ln["product_id"] = 999
        ln["unit_price"] = "79.00"

    return customers, products, fx, orders, lines, test_ids


def money_lines(lines, orders_by_id, fx_map):
    """Per-line money math shared by all legacy tools."""
    out = {}
    for ln in lines:
        o = orders_by_id[ln["order_id"]]
        qty = D(ln["quantity"])
        gross = qty * D(ln["unit_price"])
        disc = r2(gross * D(ln["discount_pct"]))
        net = gross - disc
        rate = fx_map.get((norm(o["currency_code"]), month_start(date.fromisoformat(o["order_date"]))), D(1))
        out[ln["order_line_id"]] = dict(gross=gross, disc=disc, net=net, rate=rate,
                                        gross_usd=r2(gross * rate), disc_usd=r2(disc * rate),
                                        net_usd=r2(net * rate))
    return out


def build_payments_returns(rng, orders, lines, lm):
    lines_by_order = defaultdict(list)
    for ln in lines:
        lines_by_order[ln["order_id"]].append(ln)
    payments, returns = [], []
    pay_id, ret_id = 900000, 70000
    methods = ["credit_card", "Credit Card", "paypal", "PayPal", "gift_card", "apple_pay"]
    for o in orders:
        st = norm(o["status"])
        od = date.fromisoformat(o["order_date"])
        expected = sum(lm[l["order_line_id"]]["net"] for l in lines_by_order[o["order_id"]]) + D(o["shipping_cost"])
        def add(status, amt, days):
            nonlocal pay_id
            pay_id += 1
            payments.append(dict(payment_id=pay_id, order_id=o["order_id"], payment_method=rng.choice(methods),
                                 payment_status=status, amount=str(r2(amt)),
                                 payment_date=(od + timedelta(days=days)).isoformat()))
        if st in VALID_STATUSES:
            r = rng.random()
            if r < 0.04:
                pass  # no payment at all
            elif r < 0.10:
                add(rng.choice(["failed", "FAILED"]), expected, 0)
                add(rng.choice(["captured", "Captured", "CAPTURED"]), expected, rng.randint(1, 4))
            elif r < 0.14:  # split tender
                part = r2(expected * D("0.4"))
                add("captured", part, 0)
                add("Captured", expected - part, rng.randint(0, 3))
            elif r < 0.18:
                add("captured", expected - D(rng.choice(["5.00", "0.50", "12.95", "0.02"])), rng.randint(0, 2))
            elif r < 0.21:
                add("captured", expected + D(rng.choice(["5.95", "1.00", "0.01"])), rng.randint(0, 2))
            elif r < 0.23:
                add("failed", expected, 0)
            else:
                add(rng.choice(["captured", "CAPTURED", "Captured "]), expected, rng.randint(0, 3))
            if st == "RETURNED" or rng.random() < 0.02:
                add("refunded", r2(expected * D("0.5")), rng.randint(15, 40))
        elif st == "PENDING":
            if rng.random() < 0.35:
                add("failed", expected, 0)
        elif st == "CANCELLED":
            if rng.random() < 0.3:
                add("captured", expected, 0)
        # returns
        if st in ("COMPLETED", "SHIPPED", "RETURNED", "CANCELLED"):
            p_ret = 0.65 if st == "RETURNED" else (0.07 if st != "CANCELLED" else 0.05)
            for ln in lines_by_order[o["order_id"]]:
                if ln["quantity"] == 0 or rng.random() > p_ret:
                    continue
                q = ln["quantity"]
                rq = rng.randint(1, q)
                unit_net = lm[ln["order_line_id"]]["net"] / D(q)
                ret_id += 1
                returns.append(dict(return_id=ret_id, order_line_id=ln["order_line_id"],
                                    return_date=(od + timedelta(days=rng.randint(7, 45))).isoformat(),
                                    return_qty=rq, reason_code=rng.choice(REASONS_RAW),
                                    refund_amount=str(r2(unit_net * rq))))
                if rng.random() < 0.12:  # second return on the same line, can exceed qty
                    ret_id += 1
                    returns.append(dict(return_id=ret_id, order_line_id=ln["order_line_id"],
                                        return_date=(od + timedelta(days=rng.randint(46, 80))).isoformat(),
                                        return_qty=rng.randint(1, q), reason_code=rng.choice(REASONS_RAW),
                                        refund_amount=str(r2(unit_net))))
    # orphan payments (order ids that do not exist)
    for k in range(3):
        pay_id += 1
        payments.append(dict(payment_id=pay_id, order_id=99001 + k, payment_method="credit_card",
                             payment_status="captured", amount=str(D("49.95") + k),
                             payment_date=date(2026, 3, 3 + k).isoformat()))
    return payments, returns


# ----------------------------------------------------------------------------------
# Legacy outputs
# ----------------------------------------------------------------------------------
def is_test(c):
    return norm(c["is_test_account"]) == "Y"


def legacy_customer_ltv(customers, orders, lines, returns, lm):
    """sp_load_customer_ltv"""
    cust_ok = {c["customer_id"]: c for c in customers if not is_test(c)}
    valid_orders = {o["order_id"]: o for o in orders
                    if norm(o["status"]) in VALID_STATUSES and o["customer_id"] in cust_ok
                    and date.fromisoformat(o["order_date"]) <= AS_OF_DATE}
    line_to_order = {l["order_line_id"]: l["order_id"] for l in lines}
    rev = defaultdict(D)
    ords = defaultdict(set)
    dates = defaultdict(list)
    for l in lines:
        o = valid_orders.get(l["order_id"])
        if not o:
            continue
        rev[o["customer_id"]] += lm[l["order_line_id"]]["net_usd"]
    for o in valid_orders.values():
        ords[o["customer_id"]].add(o["order_id"])
        dates[o["customer_id"]].append(date.fromisoformat(o["order_date"]))
    refunds = defaultdict(D)
    for r in returns:
        o = valid_orders.get(line_to_order[r["order_line_id"]])
        if not o:
            continue
        refunds[o["customer_id"]] += r2(D(r["refund_amount"]) * lm[r["order_line_id"]]["rate"])
    rows = []
    for cid, c in sorted(cust_ok.items()):
        n = len(ords[cid])
        pr = rev[cid] if n else D("0.00")
        rf = refunds[cid] if n else D("0.00")
        net = pr - rf
        aov = safe_div_round(pr, n, 2, f"aov {cid}") if n else D("0.00")
        first = min(dates[cid]) if n else None
        last = max(dates[cid]) if n else None
        dsl = (AS_OF_DATE - last).days if n else None
        tier = norm(c["loyalty_tier"]) or "NONE"
        # step 1: initial segment
        if n == 0:
            seg = "PROSPECT"
        elif net >= 2000:
            seg = "HIGH_VALUE"
        elif net >= 500:
            seg = "MID_VALUE"
        else:
            seg = "LOW_VALUE"
        # step 2: at-risk override
        if dsl is not None and dsl > 180 and seg in ("HIGH_VALUE", "MID_VALUE"):
            seg = "AT_RISK"
        # step 3: VIP override (wins over AT_RISK)
        if tier == "PLATINUM" and n > 0:
            seg = "VIP"
        rows.append(dict(customer_id=cid,
                         customer_name=f"{c['first_name'].strip()} {c['last_name'].strip()}",
                         email=c["email"].strip().lower(), state=norm(c["state"]), loyalty_tier=tier,
                         first_order_date=first.isoformat() if first else "",
                         last_order_date=last.isoformat() if last else "",
                         total_orders=n, product_revenue_usd=str(r2(pr)), refunds_usd=str(r2(rf)),
                         net_revenue_usd=str(r2(net)), avg_order_value_usd=str(aov),
                         days_since_last_order="" if dsl is None else dsl,
                         customer_segment=seg, etl_load_ts=ETL_LOAD_TS["ltv"]))
    return rows


CHANNEL_MAP = {"WEB": "ONLINE", "APP": "ONLINE", "STORE": "RETAIL", "MARKETPLACE": "MARKETPLACE"}


def legacy_daily_sales(customers, products, orders, lines, lm):
    """m_LOAD_DAILY_SALES_SUMMARY (Informatica)"""
    test_c = {c["customer_id"] for c in customers if is_test(c)}
    prod = {p["product_id"]: p for p in products}
    orders_by_id = {o["order_id"]: o for o in orders}
    agg = defaultdict(lambda: dict(n=0, units=0, gross=D(0), disc=D(0), net=D(0), cogs=D(0)))
    for l in lines:
        o = orders_by_id[l["order_id"]]
        if norm(o["status"]) not in VALID_STATUSES:
            continue  # SQ source filter
        if o["customer_id"] in test_c:
            continue  # FIL_EXCLUDE_TEST
        if l["quantity"] <= 0:
            continue  # FIL_EXCLUDE_TEST also drops qty <= 0
        p = prod.get(l["product_id"])
        cat = p["category"] if p else "UNKNOWN"
        cost = D(p["unit_cost"]) if p else D(0)
        ch = CHANNEL_MAP.get(norm(o["channel"]), "OTHER")
        k = (o["order_date"], ch, cat)
        m = lm[l["order_line_id"]]
        a = agg[k]
        a["n"] += 1
        a["units"] += l["quantity"]
        a["gross"] += m["gross_usd"]
        a["disc"] += m["disc_usd"]
        a["net"] += m["net_usd"]
        a["cogs"] += D(l["quantity"]) * cost
    rows = []
    for (d, ch, cat), a in sorted(agg.items()):
        margin = a["net"] - a["cogs"]
        pct = safe_div_round(margin, a["net"], 4, f"margin {d} {ch} {cat}") if a["net"] != 0 else D("0.0000")
        rows.append(dict(sales_date=d, channel_group=ch, product_category=cat, order_line_count=a["n"],
                         units_sold=a["units"], gross_sales_usd=str(r2(a["gross"])),
                         discount_usd=str(r2(a["disc"])), net_sales_usd=str(r2(a["net"])),
                         cogs_usd=str(r2(a["cogs"])), gross_margin_usd=str(r2(margin)),
                         gross_margin_pct=str(r4(pct)), etl_load_ts=ETL_LOAD_TS["sales"]))
    return rows


REASON_DESC = {"DMG": "Damaged", "SIZE": "Wrong Size", "DESC": "Not As Described", "MIND": "Changed Mind"}


def legacy_product_returns(customers, products, orders, lines, returns, lm):
    """J_Product_Returns_Analysis (Talend)"""
    test_c = {c["customer_id"] for c in customers if is_test(c)}
    prod = {p["product_id"]: p for p in products}
    orders_by_id = {o["order_id"]: o for o in orders}
    lines_by_id = {l["order_line_id"]: l for l in lines}

    def valid_line(l):
        o = orders_by_id[l["order_id"]]
        return norm(o["status"]) in VALID_STATUSES and o["customer_id"] not in test_c

    # subjob 1: returns -> per line + per reason
    line_ret = defaultdict(lambda: dict(qty=0, refund=D(0)))
    reason_qty = defaultdict(int)
    for r in returns:
        l = lines_by_id[r["order_line_id"]]
        if not valid_line(l):
            continue
        refund_usd = r2(D(r["refund_amount"]) * lm[l["order_line_id"]]["rate"])
        lr = line_ret[l["order_line_id"]]
        lr["qty"] += r["return_qty"]
        lr["refund"] += refund_usd
        reason_qty[(l["product_id"], norm(r["reason_code"]))] += r["return_qty"]
    top_reason = {}
    for (pid, code), q in sorted(reason_qty.items(), key=lambda kv: (kv[0][0], -kv[1], kv[0][1])):
        top_reason.setdefault(pid, code)
    # subjob 2: sales lines (inner join products)
    agg = defaultdict(lambda: dict(sold=0, ret=0, refund=D(0)))
    for l in lines:
        if not valid_line(l) or l["product_id"] not in prod:
            continue
        a = agg[l["product_id"]]
        a["sold"] += l["quantity"]
        lr = line_ret.get(l["order_line_id"])
        if lr:
            a["ret"] += min(lr["qty"], l["quantity"])
            a["refund"] += lr["refund"]
    rows = []
    for pid, a in sorted(agg.items()):
        p = prod[pid]
        rate = safe_div_round(a["ret"], a["sold"], 4, f"rr {pid}") if a["sold"] > 0 else D("0.0000")
        if a["sold"] >= 10 and rate >= D("0.15"):
            flag = "HIGH"
        elif rate >= D("0.08"):
            flag = "WATCH"
        else:
            flag = "NORMAL"
        code = top_reason.get(pid)
        reason = "NONE" if code is None else REASON_DESC.get(code, "Other")
        rows.append(dict(product_id=pid, sku=p["sku"], product_name=p["product_name"], category=p["category"],
                         units_sold=a["sold"], units_returned=a["ret"], return_rate=str(r4(rate)),
                         refund_amount_usd=str(r2(a["refund"])), top_return_reason=reason,
                         return_flag=flag, etl_load_ts=ETL_LOAD_TS["returns"]))
    return rows


def legacy_payment_recon(orders, lines, payments, lm):
    """Payment_Reconciliation.yxmd (Alteryx)"""
    lines_by_order = defaultdict(list)
    for l in lines:
        lines_by_order[l["order_id"]].append(l)
    ords = {o["order_id"]: o for o in orders if norm(o["status"]) != "CANCELLED"}
    pay = defaultdict(lambda: dict(cap=D(0), ncap=0, nfail=0, last=None))
    for p in payments:
        s = norm(p["payment_status"])
        a = pay[p["order_id"]]
        if s == "CAPTURED":
            a["cap"] += D(p["amount"])
            a["ncap"] += 1
            pd = date.fromisoformat(p["payment_date"])
            a["last"] = pd if a["last"] is None or pd > a["last"] else a["last"]
        elif s == "FAILED":
            a["nfail"] += 1
    rows = []
    for oid, o in sorted(ords.items()):
        if not lines_by_order[oid]:
            continue  # inner join to line totals
        expected = sum(lm[l["order_line_id"]]["net"] for l in lines_by_order[oid]) + D(o["shipping_cost"])
        od = date.fromisoformat(o["order_date"])
        if oid in pay:
            a = pay[oid]
            var = r2(a["cap"] - expected)
            if a["ncap"] == 0:
                status = "NO_PAYMENT"
            elif abs(var) <= D("0.01"):
                status = "MATCHED"
            elif var < 0:
                status = "UNDERPAID"
            else:
                status = "OVERPAID"
            cap, ncap, nfail, last = a["cap"], a["ncap"], a["nfail"], a["last"]
        else:
            cap, ncap, nfail, last = D(0), 0, 0, None
            var = r2(-expected)
            status = "NO_PAYMENT"
        rows.append(dict(order_id=oid, customer_id=o["customer_id"], order_date=o["order_date"],
                         order_status=norm(o["status"]), currency_code=norm(o["currency_code"]),
                         expected_amount=str(r2(expected)), captured_amount=str(r2(cap)),
                         variance_amount=str(var), captured_payment_count=ncap, failed_payment_count=nfail,
                         last_captured_date=last.isoformat() if last else "",
                         days_to_payment="" if last is None else (last - od).days,
                         reconciliation_status=status, etl_load_ts=ETL_LOAD_TS["recon"]))
    for oid in sorted(set(pay) - set(ords)):
        a = pay[oid]
        rows.append(dict(order_id=oid, customer_id="", order_date="", order_status="", currency_code="",
                         expected_amount="", captured_amount=str(r2(a["cap"])),
                         variance_amount=str(r2(a["cap"])), captured_payment_count=a["ncap"],
                         failed_payment_count=a["nfail"],
                         last_captured_date=a["last"].isoformat() if a["last"] else "",
                         days_to_payment="", reconciliation_status="UNMATCHED_PAYMENT",
                         etl_load_ts=ETL_LOAD_TS["recon"]))
    rows.sort(key=lambda r: r["order_id"])
    return rows


def write_csv(path, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)


def main(root, seed):
    global AMBIGUOUS
    AMBIGUOUS = []
    rng = random.Random(seed)
    customers, products, fx, orders, lines, _ = build_raw(rng)
    orders_by_id = {o["order_id"]: o for o in orders}
    fx_map = {(f["currency_code"], date.fromisoformat(f["rate_month"])): D(f["usd_per_unit"]) for f in fx}
    lm = money_lines(lines, orders_by_id, fx_map)
    payments, returns = build_payments_returns(rng, orders, lines, lm)

    ltv = legacy_customer_ltv(customers, orders, lines, returns, lm)
    sales = legacy_daily_sales(customers, products, orders, lines, lm)
    prr = legacy_product_returns(customers, products, orders, lines, returns, lm)
    rec = legacy_payment_recon(orders, lines, payments, lm)
    if AMBIGUOUS:
        return False, AMBIGUOUS

    root = Path(root)
    raw = root / "seeds" / "raw"
    leg = root / "seeds" / "legacy_targets"
    write_csv(raw / "customers.csv", customers)
    write_csv(raw / "products.csv", products)
    write_csv(raw / "fx_rates.csv", fx)
    write_csv(raw / "orders.csv", orders)
    write_csv(raw / "order_lines.csv", lines)
    write_csv(raw / "payments.csv", payments)
    write_csv(raw / "returns.csv", returns)
    write_csv(leg / "legacy_customer_ltv.csv", ltv)
    write_csv(leg / "legacy_daily_sales_summary.csv", sales)
    write_csv(leg / "legacy_product_returns_summary.csv", prr)
    write_csv(leg / "legacy_payment_reconciliation.csv", rec)
    return True, dict(customers=len(customers), products=len(products), fx=len(fx), orders=len(orders),
                      lines=len(lines), payments=len(payments), returns=len(returns), ltv=len(ltv),
                      sales=len(sales), product_returns=len(prr), recon=len(rec))


if __name__ == "__main__":
    root = sys.argv[1] if len(sys.argv) > 1 else "."
    seed = 2394  # first seed (searching from 2026) with no engine-sensitive rounding
    while True:
        ok, info = main(root, seed)
        if ok:
            print(f"seed={seed}", info)
            break
        print(f"seed={seed} rejected: {len(info)} rounding-ambiguous values, retrying")
        seed += 1
