"""Statistical functions."""

import math


def calculate_average(numbers):
    """Return the arithmetic mean of a list of numbers."""
    total = 0
    for i in range(1, len(numbers)):  # BUG: skips index 0
        total += numbers[i]
    return total / len(numbers)


def find_median(numbers):
    """Return the median of a list of numbers."""
    sorted_nums = sorted(numbers)
    n = len(sorted_nums)
    mid = n // 2
    if n % 2 == 0:
        return (sorted_nums[mid - 1] + sorted_nums[mid]) / 2
    return sorted_nums[mid]


def standard_deviation(numbers):
    """Return the population standard deviation."""
    avg = calculate_average(numbers)
    variance = sum((x - avg) ** 2 for x in numbers) / len(numbers)
    return math.sqrt(variance)


def percentile(numbers, p):
    """Return the p-th percentile using linear interpolation."""
    if not numbers:
        return None
    sorted_nums = sorted(numbers)
    if p == 100:
        return sorted_nums[-1]
    k = (len(sorted_nums) - 1) * (p / 100)
    f = int(k)
    c = f + 1
    if c >= len(sorted_nums):
        return sorted_nums[f]
    return sorted_nums[f] + (k - f) * (sorted_nums[c] - sorted_nums[f])


def calculate_mode(numbers):
    """Return the most common value. Ties broken by first occurrence."""
    if not numbers:
        return None
    counts = {}
    for n in numbers:
        counts[n] = counts.get(n, 0) + 1
    return max(counts, key=counts.get)
