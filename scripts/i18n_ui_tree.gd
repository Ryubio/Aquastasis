extends RefCounted
## String table (policy tree modal and event card chrome (buttons, labels, states). Owner: tree UI module (en), localization (tr/ru)) merged by the I18n autoload; never read directly by game code.
## Format: key -> {"tr": ..., "en": ..., "ru": ...}. Keys are unique across all tables.

const STRINGS := {
	# --- Policy tree: header ---
	"ui.tree.title": {"en": "POLICY TREE"},
	"ui.tree.subtitle": {"en": "COP31 Marine Coalition · permanent policies · time is paused"},
	"ui.tree.adopted_count": {"en": "Adopted: {n}/{total}"},
	"ui.tree.close": {"en": "Close"},
	"ui.tree.hint": {"en": "Click a policy for details · double-click to adopt"},
	"ui.tree.tier": {"en": "Tier {n}"},

	# --- Policy tree: node states ---
	"ui.tree.state.locked": {"en": "LOCKED"},
	"ui.tree.state.available": {"en": "AVAILABLE"},
	"ui.tree.state.affordable": {"en": "READY TO ADOPT"},
	"ui.tree.state.adopted": {"en": "ADOPTED"},
	"ui.tree.state.ramping": {"en": "IMPLEMENTING {pct}"},

	# --- Policy tree: details pane ---
	"ui.tree.cost": {"en": "COST"},
	"ui.tree.free": {"en": "Free"},
	"ui.tree.requires": {"en": "REQUIRES"},
	"ui.tree.requires_none": {"en": "No prerequisites: a starting policy."},
	"ui.tree.effect": {"en": "EFFECT"},
	"ui.tree.counters": {"en": "COUNTERS RESISTANCE"},
	"ui.tree.counter.active": {"en": "Active now: adopting this policy cures it."},
	"ui.tree.counter.immune": {"en": "In force: the crisis can no longer evolve this resistance."},
	"ui.tree.counter.prevent": {"en": "Not active yet. Adopting this policy makes the crisis immune to it."},
	"ui.tree.real_world": {"en": "REAL WORLD"},
	"ui.tree.adopt": {"en": "ADOPT POLICY"},
	"ui.tree.adopted_button": {"en": "POLICY IN FORCE"},
	"ui.tree.locked_button": {"en": "LOCKED"},
	"ui.tree.why.ready": {"en": "Spending is permanent. Its effect ramps in over time."},
	"ui.tree.why.locked": {"en": "Adopt the required policies first."},
	"ui.tree.why.cost": {"en": "Not enough resources yet. Collect data bubbles and keep the sea healthy."},
	"ui.tree.why.event": {"en": "Answer the decision card first."},
	"ui.tree.why.ramping": {"en": "Implementation: {pct}"},
	"ui.tree.why.done": {"en": "Fully implemented."},
	"ui.tree.why.no_game": {"en": "Start a game to adopt policies."},
	"ui.tree.adopt_failed": {"en": "Adoption refused: check the cost and prerequisites."},

	# --- Policy tree: evolution strip ---
	"ui.tree.evo.title": {"en": "CRISIS ADAPTATION"},
	"ui.tree.evo.hint": {"en": "If one branch dominates your recent moves, the crisis evolves a resistance against it."},
	"ui.tree.evo.moves": {"en": "Recent moves: {n} · evolves from {m}"},
	"ui.tree.evo.limit": {"en": "Limit: {pct}"},
	"ui.tree.evo.active_tag": {"en": "RESISTANT"},
	"ui.tree.evo.resist_title": {"en": "ACTIVE RESISTANCES"},
	"ui.tree.evo.none": {"en": "None so far. A varied strategy keeps it that way."},
	"ui.tree.evo.cure": {"en": "Cure:"},
	"ui.tree.evo.more": {"en": "Also active: {n}"},

	# --- Decision card ---
	"ui.card.kind.alert": {"en": "ECOLOGICAL ALERT"},
	"ui.card.kind.pressure": {"en": "POLITICAL PRESSURE"},
	"ui.card.kind.opportunity": {"en": "OPPORTUNITY"},
	"ui.card.kind.summit": {"en": "COP31 SUMMIT"},
	"ui.card.decision": {"en": "DECISION REQUIRED"},
	"ui.card.paused": {"en": "Time is paused until you decide."},
	"ui.card.basin_wide": {"en": "Whole basin"},
	"ui.card.free": {"en": "No cost"},
	"ui.card.tone.pos": {"en": "PROTECTS THE SEA"},
	"ui.card.tone.neutral": {"en": "TRADE-OFF"},
	"ui.card.tone.neg": {"en": "RISKY"},
	"ui.card.cant_afford": {"en": "Not enough resources"},
	"ui.card.outcome": {"en": "OUTCOME"},
	"ui.card.you_chose": {"en": "Decision: {choice}"},
	"ui.card.continue": {"en": "Continue"},
	"ui.card.keys_choose": {"en": "Press 1 or 2 to choose"},
	"ui.card.keys_continue": {"en": "Enter: continue"},
	"ui.card.unknown_title": {"en": "Unexpected Development"},
	"ui.card.unknown_text": {"en": "Something is happening in the basin. Choose how the coalition responds."},
}
