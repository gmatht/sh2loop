import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const STATE_TYPE = "goal-continuation-state";
const DEFAULT_MAX_TURNS = 20;

type State = {
  enabled: boolean;
  turns: number;
  maxTurns: number;
};

function textOf(value: unknown): string {
  if (typeof value === "string") return value;
  if (Array.isArray(value)) return value.map(textOf).join("\n");
  if (!value || typeof value !== "object") return "";
  const record = value as Record<string, unknown>;
  return [record.content, record.message, record.text].map(textOf).join("\n");
}

function hasActiveGoal(ctx: ExtensionContext): boolean {
  const context = ctx.sessionManager
    .getBranch()
    .map((entry) => textOf(entry))
    .join("\n");
  return /<goal_context\b[\s\S]*?Status:\s*active[\s\S]*?<\/goal_context>/i.test(context)
    || /Status:\s*active[\s\S]*?Acceptance criteria:/i.test(context);
}

export default function (pi: ExtensionAPI) {
  pi.registerFlag("local-goal-continuation", {
    description: "Automatically continue an active goal after each settled agent turn (local extension)",
    type: "boolean",
    default: false,
  });

  let state: State = {
    enabled: pi.getFlag("local-goal-continuation") === true,
    turns: 0,
    maxTurns: DEFAULT_MAX_TURNS,
  };
  let continuationPending = false;

  const persist = () => {
    pi.appendEntry(STATE_TYPE, { ...state });
  };

  pi.on("session_start", async (_event, ctx) => {
    const entries = ctx.sessionManager.getEntries();
    for (let i = entries.length - 1; i >= 0; i--) {
      const entry = entries[i];
      if (entry.type !== "custom" || entry.customType !== STATE_TYPE) continue;
      const data = entry.data as Partial<State> | undefined;
      state = {
        enabled: data?.enabled === true,
        turns: Number.isFinite(data?.turns) ? Number(data?.turns) : 0,
        maxTurns: Number.isFinite(data?.maxTurns) && Number(data?.maxTurns) > 0
          ? Number(data?.maxTurns)
          : DEFAULT_MAX_TURNS,
      };
      break;
    }
    if (pi.getFlag("local-goal-continuation") === true) state.enabled = true;
    if (state.enabled) persist();
  });

  pi.registerCommand("goal-continuation", {
    description: "Enable/disable automatic continuation: on, off, status, or once",
    handler: async (args, ctx) => {
      const command = (args ?? "").trim().toLowerCase();
      if (command === "off") {
        state.enabled = false;
        continuationPending = false;
        persist();
        ctx.ui.notify("Goal continuation disabled.", "info");
        return;
      }
      if (command === "status") {
        ctx.ui.notify(
          `Goal continuation: ${state.enabled ? "on" : "off"} (${state.turns}/${state.maxTurns})`,
          "info",
        );
        return;
      }
      if (command === "once") {
        pi.sendUserMessage("Continue working toward the active goal. Verify progress with the required gates.");
        return;
      }
      state.enabled = true;
      state.turns = 0;
      if (command.startsWith("max=")) {
        const max = Number(command.slice(4));
        if (Number.isFinite(max) && max > 0) state.maxTurns = Math.floor(max);
      }
      persist();
      ctx.ui.notify(`Goal continuation enabled (max ${state.maxTurns} turns).`, "info");
    },
  });

  pi.on("agent_start", async () => {
    continuationPending = false;
  });

  pi.on("agent_settled", async (_event, ctx) => {
    // Enabling this mode is the explicit user opt-in. Do not depend on
    // parsing goal_context text: that context may be supplied by the host
    // rather than stored as a normal session message.
    if (!state.enabled || continuationPending) return;
    if (state.turns >= state.maxTurns) {
      state.enabled = false;
      persist();
      ctx.ui.notify("Goal continuation stopped at its turn limit.", "warning");
      return;
    }
    continuationPending = true;
    state.turns += 1;
    persist();
    pi.sendUserMessage(
      "Continue working toward the active goal now. Inspect the current state, implement the next safe change, run the relevant verification gates, and report progress honestly.",
    );
  });
}
