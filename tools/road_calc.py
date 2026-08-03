#!/usr/bin/env python3
"""Generate the route control points of data/map_route.tres.

The route is a straight lead-in, a sine of sweeping bends, and a straight
run-out. This script solves for the sine amplitude that makes the baked curve
length come out at the target, and reports the turn rate the bends demand so the
route can be checked against the cargo turn rate of specification section 13.1.

The length model matches what Godot does: Map.gd derives each control point's
tangent from its neighbours (a Catmull-Rom style tangent of one sixth the span),
and Curve2D then bakes cubic Beziers between the points. Reproducing that here is
what makes the printed length agree with Curve2D.get_baked_length() in game.

Usage:
    python3 tools/road_calc.py [--target 9000] [--wavelength 2800]
"""

from __future__ import annotations

import argparse
import math

STEP = 350.0  # control point spacing along x, one eighth of the wavelength
LEAD = 600.0  # straight practice area before the first bend
RUNOUT = 600.0  # straight approach to the final portal
FLAT_CYCLES = 2.25  # ends the sine on a zero-slope point so the run-out is flat


def build_points(amplitude: float, wavelength: float) -> list[tuple[float, float]]:
    sine_end = FLAT_CYCLES * wavelength
    points = [(-LEAD, 0.0), (-LEAD / 2.0, 0.0)]
    steps = int(round(sine_end / STEP))
    for i in range(steps + 1):
        x = i * STEP
        points.append((x, amplitude * math.sin(2.0 * math.pi * x / wavelength)))
    end_y = amplitude * math.sin(2.0 * math.pi * sine_end / wavelength)
    points.append((sine_end + RUNOUT / 2.0, end_y))
    points.append((sine_end + RUNOUT, end_y))
    return points


def bezier(p0, c0, c1, p1, t):
    u = 1.0 - t
    return (
        u**3 * p0[0] + 3 * u * u * t * c0[0] + 3 * u * t * t * c1[0] + t**3 * p1[0],
        u**3 * p0[1] + 3 * u * u * t * c0[1] + 3 * u * t * t * c1[1] + t**3 * p1[1],
    )


def baked_length(points, samples: int = 40) -> float:
    count = len(points)
    tangents = []
    for i in range(count):
        before = points[max(0, i - 1)]
        after = points[min(count - 1, i + 1)]
        tangents.append(((after[0] - before[0]) / 6.0, (after[1] - before[1]) / 6.0))

    total = 0.0
    for i in range(count - 1):
        p0, p1 = points[i], points[i + 1]
        c0 = (p0[0] + tangents[i][0], p0[1] + tangents[i][1])
        c1 = (p1[0] - tangents[i + 1][0], p1[1] - tangents[i + 1][1])
        previous = p0
        for k in range(1, samples + 1):
            current = bezier(p0, c0, c1, p1, k / samples)
            total += math.dist(previous, current)
            previous = current
    return total


def solve_amplitude(target: float, wavelength: float) -> float:
    low, high = 50.0, 1500.0
    for _ in range(80):
        mid = (low + high) / 2.0
        if baked_length(build_points(mid, wavelength)) < target:
            low = mid
        else:
            high = mid
    return round((low + high) / 2.0, 1)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", type=float, default=9000.0, help="baked length in pixels")
    parser.add_argument("--wavelength", type=float, default=2800.0)
    parser.add_argument("--turn-rate", type=float, default=80.0, help="degrees per second, section 13.1")
    parser.add_argument("--fast-speed", type=float, default=65.0, help="pixels per second, section 13.1")
    args = parser.parse_args()

    amplitude = solve_amplitude(args.target, args.wavelength)
    points = build_points(amplitude, args.wavelength)
    length = baked_length(points)

    # Maximum curvature of y = A sin(kx) is A k squared, at the crest of each bend.
    k = 2.0 * math.pi / args.wavelength
    curvature = amplitude * k * k
    radius = 1.0 / curvature
    demand = math.degrees(args.fast_speed * curvature)

    print(f"amplitude        {amplitude}")
    print(f"wavelength       {args.wavelength}")
    print(f"control points   {len(points)}")
    print(f"baked length     {length:.1f}  (target {args.target:.0f})")
    print(f"min turn radius  {radius:.0f}px")
    print(f"turn demand      {demand:.1f} deg/s at {args.fast_speed:.0f}px/s  (limit {args.turn_rate:.0f})")
    if demand > args.turn_rate:
        print("WARNING: the bends ask for more turn rate than the cargo has.")
    print(f"inner edge radius {radius - 210.0:.0f}px  (road half width 210)")
    print()
    print("control_points = PackedVector2Array(", end="")
    print(", ".join(f"{x:.0f}, {y:.1f}".replace(".0", "") if y == int(y) else f"{x:.0f}, {y:.1f}"
                    for x, y in points), end="")
    print(")")


if __name__ == "__main__":
    main()
