"""Tests for statistical functions.

Some tests FAIL against the shipped code — this is intentional.
The benchmark tasks require fixing the bugs to make them pass.
"""

import pytest

from src.stats import (
    calculate_average,
    calculate_mode,
    find_median,
    percentile,
    standard_deviation,
)


# --- calculate_average ---


class TestCalculateAverage:
    def test_basic(self):
        assert calculate_average([1, 2, 3, 4, 5]) == 3.0

    def test_single_element(self):
        assert calculate_average([42]) == 42.0

    def test_negative_numbers(self):
        assert calculate_average([-1, 0, 1]) == 0.0

    def test_two_elements(self):
        assert calculate_average([10, 20]) == 15.0

    def test_floats(self):
        assert abs(calculate_average([1.5, 2.5, 3.5]) - 2.5) < 1e-10

    def test_empty_raises(self):
        with pytest.raises(ValueError):
            calculate_average([])


# --- find_median ---


class TestFindMedian:
    def test_odd_count(self):
        assert find_median([3, 1, 2]) == 2

    def test_even_count(self):
        assert find_median([1, 2, 3, 4]) == 2.5

    def test_single(self):
        assert find_median([5]) == 5

    def test_already_sorted(self):
        assert find_median([1, 2, 3]) == 2

    def test_empty_raises(self):
        with pytest.raises(ValueError):
            find_median([])


# --- standard_deviation ---


class TestStandardDeviation:
    def test_uniform(self):
        assert standard_deviation([5, 5, 5]) == 0.0

    def test_basic(self):
        result = standard_deviation([2, 4, 4, 4, 5, 5, 7, 9])
        assert abs(result - 2.0) < 0.01

    def test_two_values(self):
        result = standard_deviation([0, 10])
        assert abs(result - 5.0) < 0.01

    def test_empty_raises(self):
        with pytest.raises(ValueError):
            standard_deviation([])


# --- percentile ---


class TestPercentile:
    def test_p50_is_median(self):
        assert percentile([1, 2, 3, 4, 5], 50) == 3.0

    def test_p0(self):
        assert percentile([10, 20, 30], 0) == 10

    def test_p100(self):
        assert percentile([10, 20, 30], 100) == 30

    def test_p25(self):
        result = percentile([1, 2, 3, 4], 25)
        assert abs(result - 1.75) < 0.01

    def test_empty(self):
        assert percentile([], 50) is None


# --- calculate_mode ---


class TestCalculateMode:
    def test_single_mode(self):
        assert calculate_mode([1, 2, 2, 3]) == 2

    def test_all_same(self):
        assert calculate_mode([7, 7, 7]) == 7

    def test_empty(self):
        assert calculate_mode([]) is None
