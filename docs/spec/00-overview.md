# Overview — §1–7, §44

Fantasy Convoy MVP Proof of Concept Specification, document version 0.1.
Engine: Godot 4.x. Language style: ASD-STE100-based simplified technical English.

> This document uses short sentences, active voice, defined technical terms, and one
> topic in each paragraph. It does not claim formal ASD-STE100 certification.

## 1. Purpose

This proof of concept tests the main battlefield controls.

The test must show how one player controls three systems at the same time.

The three systems are the cargo unit, the defenders, and the wizard.

The proof of concept does not test contracts, salaries, upgrades, or campaign
progression.

The proof of concept must use one fixed battlefield.

The project must support different control profiles on the same battlefield.

The test results must show which control profile is clear, difficult, and fun.

## 2. Main design decision

The game uses indirect control for the defenders.

The player does not move a defender with movement keys.

The player selects defenders and gives orders.

The defender artificial intelligence executes each order.

The player controls the wizard with the mouse.

The player controls the cargo unit with the keyboard.

These input groups stay active at the same time.

The player does not enter a separate wizard mode or defender mode.

## 3. MVP scope

The proof of concept contains these systems:

- One cargo unit
- One rider prop
- One wizard
- Four defenders
- One short-range enemy type
- One long-range enemy type
- One fixed map
- One road
- Two terrain types
- Two barriers
- One final portal
- Three wizard spells
- Two defender control methods
- Three cargo control methods
- Four test profiles
- One result screen
- One telemetry file

## 4. Items outside the MVP scope

The proof of concept does not contain these systems:

- Contracts
- Money
- Salaries
- Crew recruitment
- Permanent injuries
- Permanent upgrades
- Multiple dimensions
- Random map generation
- Inventory
- Equipment
- Dialogue
- Story content
- Boss combat
- Online functions
- Save-game progression

## 5. Technical terms

### 5.1 Cargo unit

The **cargo unit** is the wagon, the rider prop, and the wizard platform.

The cargo unit has one collision shape and one health value.

### 5.2 Defender

A **defender** is an autonomous crew unit near the cargo unit.

A defender can attack enemies, protect the cargo unit, and do repair work.

### 5.3 Order

An **order** is a player command for one or more selected defenders.

An order changes the active defender state.

### 5.4 Control profile

A **control profile** is one fixed combination of cargo control and defender
control.

### 5.5 Engagement radius

The **engagement radius** is the maximum distance for an automatic defender attack.

The center of this radius is the cargo unit.

### 5.6 Leash radius

The **leash radius** is the maximum distance that a defender can move from the
cargo unit.

### 5.7 Work point

A **work point** is a position for cargo repair or barrier removal.

### 5.8 Threat value

The **threat value** is a value that increases during a run.

A high threat value causes more enemy attacks.

## 6. Game objective

The player must move the cargo unit from the start area to the final portal.

The player must keep the cargo health above zero.

The player completes the run after the final portal cast.

The player fails the run when the cargo health becomes zero.

The player can continue after all defenders die.

The player cannot replace a defender during a run.

## 7. Run duration

One run must take between three minutes and six minutes.

A fast and successful run can finish in approximately three minutes.

A slow run must cause more enemy attacks.

A run must not continue for more than eight minutes.

The game must end the run after eight minutes.

This time limit prevents invalid test sessions.

> **Build note.** The three-minute floor is not reachable until both barriers are in
> the route. See the open findings in [`../status.md`](../status.md).

## 44. Language note

This specification uses necessary game terms as technical nouns.

Examples include cargo unit, control profile, engagement radius, state machine, and
telemetry.

The text uses short descriptive sentences and direct procedural instructions.

A formal ASD-STE100 checker did not verify this document.
