# Testing the interest rate model

# Parameters
BLOCK_PERIOD = 1000

def calculate_linear_interest(rate_per_period, last_update_timestamp, current_timestamp):
    """Return interest multiplier using simple interest."""
    time_elapsed = current_timestamp - last_update_timestamp
    time_elapsed_ratio = time_elapsed / BLOCK_PERIOD
    return 1 + rate_per_period * time_elapsed_ratio # multiplier

# System parameters
borrow_rate = 0.40  # 40% borrow rate per period

borrow_index = 1.0      # global borrow index starts at 1.0
last_update = 0         # last time when global borrow index was updated
total_debt = 0          # total debt 
total_debt_index = 1.0  # borrow index at last borrow/repay

# User data - tracks when each user last interacted
users = {
    'A': {'debt': 0.0, 'borrow_index': 1.0},
    'B': {'debt': 0.0, 'borrow_index': 1.0}
}

def update_global_index(current_time):
    """Update global borrow index based on time elapsed."""
    global borrow_index, last_update
    
    if current_time > last_update:
        multiplier = calculate_linear_interest(borrow_rate, last_update, current_time)
        print(f"multiplier: {multiplier}")
        borrow_index *= multiplier
        last_update = current_time
        # print(f"Global index updated to {borrow_index:.9f} at t={current_time}")

def get_accrued_debt(user_id):
    """Calculate user's current debt including accrued interest."""
    user = users[user_id]
    return user['debt'] * (borrow_index / user['borrow_index'])

def borrow(user_id, amount, current_time):
    global total_debt, total_debt_index

    """Process a user borrowing operation."""
    # First update global index
    update_global_index(current_time)
    
    # Get user's current accrued debt
    current_debt = get_accrued_debt(user_id)
    
    # Update user's debt and index
    users[user_id]['debt'] = current_debt + amount
    users[user_id]['borrow_index'] = borrow_index    

    # Accrue total borrowed
    total_debt_now = total_debt * (borrow_index / total_debt_index)
    total_debt = total_debt_now + amount
    total_debt_index = borrow_index

    print(f"\n{user_id}:borrow({amount}) at t={current_time}")

def get_total_debt():
    return total_debt * (borrow_index / total_debt_index)

def show_all_debts(current_time):
    """Display all users' current debt including accrued interest."""
    update_global_index(current_time)
    print(f"\nt={current_time}: borrow_index = {borrow_index:.9f}")
    
    for user_id in users:
        accrued_debt = get_accrued_debt(user_id)
        print(f"    {user_id}: {accrued_debt:.6f} (base: {users[user_id]['debt']:.6f}, index: {users[user_id]['borrow_index']:.9f})")

    print(f"    Total debt: {get_total_debt():.6f} (total_debt_index: {total_debt_index:.6f})")

# Simulation

# Initial state

borrow('A', 400.0, 250)
show_all_debts(250)

borrow('B', 200.0, 500)
show_all_debts(500)

borrow('A', -200.0, 750)
show_all_debts(750)

show_all_debts(1000)

show_all_debts(1250)

