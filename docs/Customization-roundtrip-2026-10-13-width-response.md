The new feedback changes the first-slice geometry priority: width should become content-driven and tightly capped rather than preserving the current fixed-wing reservation. The amendment below leaves the broader O5–O9 roadmap intact.

## Amendment to O6 first-slice geometry and Settings recommendation

New user feedback establishes an additional first-slice requirement: the current side-wing glance is still too wide and consumes excessive menu-bar space even though its vertical height is now acceptable.

The supplied screenshot description shows a left label containing a course/task identifier plus weekday/time and a much shorter countdown on the right. The current approximately 90-point-per-side fixed allocation therefore appears to reserve substantially more horizontal space than some content requires.

Treat **lateral footprint reduction** as a primary O6 acceptance goal, not a later polish item.

Do not change the broader roadmap: O6 remains the preferred first implementation slice unless source inspection reveals a stronger dependency; O5 must still include both supported per-cue haptic controls and the separate genuine haptic-intensity investigation; O7–O9 remain in the roadmap as previously specified.

### Revised O6 product rule

The closed notch should occupy **only the horizontal space needed for useful information, up to a strict cap**, while keeping the physical hardware-notch region visually and geometrically stable.

Do not assume that independently shrinking one child of a centered `HStack`, spacer arrangement or similar SwiftUI composition automatically preserves alignment with the physical notch. The executor must first determine how the current notch geometry anchors:

- the hardware-notch center region;
- left and right extension frames;
- hit-testing areas;
- background/shape drawing;
- animation between states.

The physical-notch center must remain anchored to the display/notch geometry regardless of asymmetric left/right content widths.

### Compact default proposal

Make the default closed-glance presentation intentionally terse.

#### Left wing

Default to a **short task identity**, not a repeated schedule sentence.

Preferred information order:

1. short explicit task/course identity if one exists;
2. concise title truncated to the available maximum;
3. no repeated weekday/time when that information is already conveyed by the countdown or Today card.

For example, prefer the conceptual equivalent of:

`CSCI · Problem Set`

over:

`CSCI · Tuesday 3:00 PM · Problem Set`

when the right wing already communicates time-to-deadline.

Do not invent abbreviation logic that destroys meaning. Inspect the actual Today payload/model fields and determine whether a reliable short identity already exists. If it does not, define a conservative truncation/fallback rule rather than heuristically rewriting arbitrary task titles.

#### Right wing

Show the compact countdown/status only.

Use a width policy that avoids visible resizing every second or minute. Prefer one of:

- a fixed width sized for the longest representation used by that countdown mode; or
- a small set of stable width buckets for defined states.

Do not content-fit the countdown character by character if doing so causes the wing/background to pulse laterally as values change.

The right wing may therefore reserve a small amount of predictable internal space while still being much narrower than the current fixed 90-point allocation.

#### Overall geometry

Prefer:

- independent left and right **content-derived target widths**;
- a minimum width only where necessary for legibility/hit targets;
- a **strict per-side maximum extension**;
- a separate stable hardware-notch center anchor;
- asymmetric left/right extensions when their content differs.

Do not force visual symmetry merely to keep the hardware notch centered. Center the hardware-notch region explicitly and let the two outward extensions differ.

The implementation should distinguish:

- **hardware-notch center alignment**, which must remain fixed;
- **left extension width**;
- **right extension width**.

Changing one extension must not translate the center region.

### Width cap and menu-bar reserve

Add a small, understandable width setting rather than unrestricted sizing.

Recommended first-slice Settings shape:

**Closed Notch Width**
- Compact — default
- Balanced
- Maximum

These should correspond to explicit maximum outward extension values derived from the current notch/display geometry after inspection.

If a simple numeric width control fits existing Settings conventions better, it may be used instead, but constrain it to a safe bounded range and provide a sensible compact default.

Also preserve a configurable or hard-coded **outer reserve margin** so a fully expanded permitted wing does not intentionally consume the entire available menu-bar span.

The executor must not claim automatic avoidance of menu-bar icons unless the application actually obtains reliable information about their occupied regions.

### Menu-bar collision boundary

Separate two capabilities clearly.

**In first-slice scope:** geometry that is intrinsically conservative:
- content fitting;
- strict maximum extension;
- outer reserve margin;
- predictable truncation;
- compact default labels.

**Not automatically implied:** detecting the live positions of arbitrary macOS menu-bar items and dynamically stopping before them.

Investigate whether the existing app already has a supported source of menu-bar geometry. If not, treat reliable automatic collision detection as a separate feature requiring additional mechanism, API research, accessibility access or other system integration.

Do not request new permissions merely for this first slice.

Do not infer "no collision" from the absence of overlap on one machine or screenshot.

### Executor inspection requirements

Before selecting concrete dimensions or changing the future implementation prompt, inspect the verified current integration for:

1. the actual closed-notch frame and shape calculation;
2. where the approximately 90-point wing widths are imposed;
3. whether width affects the center notch frame or only outward extensions;
4. whether hit regions use the visible frame or a larger fixed frame;
5. transitions between deadline, focus, media, battery, notification and hidden states;
6. how the current left label is assembled and which payload fields are available for a shorter identity;
7. all countdown/status strings that can occupy the right side, including their longest normal forms;
8. font metrics/padding that dominate minimum practical width;
9. display/notch-width differences across supported machines;
10. whether any existing source already tracks usable menu-bar space or item locations.

Do not invent fixed replacement numbers before this inspection.

### Revised first-slice Settings proposal

The O6 first slice should preferably expose only:

**Closed Notch Content**
- Left content
- Right content
- deadline visibility horizon
- hidden option

**Closed Notch Size**
- width mode/cap: Compact / Balanced / Maximum
- existing normal-height behavior remains unchanged

Avoid adding independent arbitrary left/right pixel sliders in v1. The product goal is compact predictable behavior, not manual geometry repair by the user.

If content choice permits one side to be empty, the empty side should collapse to the minimum structurally necessary extension rather than retaining the old fixed reservation.

### Observable acceptance for compact geometry

For the supported first-slice combinations, acceptance must demonstrate all of the following:

- The hardware-notch center region has the same display-relative center before and after left/right content widths change.
- A short right countdown does not reserve the previous full fixed-wing width unless required by an explicitly documented stable countdown bucket.
- Hiding one side materially reduces that side's outward footprint.
- Long left content truncates or shortens within the configured cap rather than expanding indefinitely.
- The default left label does not unnecessarily repeat date/time information already expressed by the right countdown when a meaningful shorter identity is available.
- Countdown updates do not cause distracting frame-width jitter during ordinary ticking.
- Transitioning between supported deadline/focus/media states does not visibly drag the hardware-notch region left or right.
- Visible backgrounds and hit targets shrink together; collapsed space does not remain invisibly clickable.
- The chosen Compact default consumes less lateral menu-bar space than the current fixed two-wing layout for representative short-content cases.
- Maximum extension remains bounded even for pathological/long text.
- Fullscreen, hidden and zero-height suppression behavior remains unchanged.
- No acceptance claim says the implementation automatically avoids arbitrary menu-bar icons unless live icon-region detection was actually implemented and verified.

### Runtime scenarios for the future implementation pass

When runtime execution is separately authorized, inspect at least:

- short left identity + short countdown;
- long task title + short countdown;
- left content only;
- right content only;
- both sides hidden;
- countdown crossing representation boundaries, such as hours to minutes;
- deadline → due reminder;
- deadline → media → deadline;
- focus active → focus ending;
- narrow versus wider supported display/notch geometries where available.

Record the center position and effective left/right outer bounds, not just screenshots.

### First-slice handoff adjustment

Update the future implementation handoff so O6 v1 explicitly optimizes for:

> a compact, content-fitting closed notch with independently sized outward wings, a fixed hardware-notch center anchor, a strict extension cap, stable countdown width and terse default task identity.

The executor must choose concrete widths only after inspecting the current geometry and actual string variants.

Do not broaden this amendment into live menu-bar-item avoidance unless existing source makes that capability readily available without new permissions or disproportionate scope.

The concrete default I would carry forward is: **short task/course identity on the left, stable compact countdown on the right, independent content-fitting side widths, Compact as the default cap, and an explicitly anchored center notch frame**. That directly addresses the described wasted space without betting the first slice on much harder live menu-bar collision detection.