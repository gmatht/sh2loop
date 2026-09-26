# harness/ai_fallback.pm — shared Laguna daily-quota fallback for the Perl loops.
#
# Both main_loop_rust.pl and main_loop_estree.pl stream the AI child's output
# and must react identically to OpenRouter's daily-free quota error. Keeping
# the detection here means the two loops cannot drift apart.
#
# WHY STREAM-BASED, NOT EXIT-BASED: `pir` retries a 429 internally, forever,
# before it ever returns to the caller (the C worker log shows attempts 1->19
# of the same free-models-per-day error with no process exit in between). So a
# worker cannot learn about the quota from the child's exit status — the child
# never exits. It CAN read the streamed notice, which appears on the first
# failed attempt, long before any model content.

package ai_fallback;

use strict;
use warnings;

# OpenRouter's daily-free quota error code. It is OpenRouter's own string and
# does not occur in the transpiler corpus, so "model is Laguna AND the output
# carries this marker" is a sufficient guard.
our $QUOTA_MARKER = 'free-models-per-day';

# The Laguna model id. THIS MUST MATCH WHAT THE WORKERS ACTUALLY RUN.
#
# Both loops default to the OpenRouter-style COLON form
# `poolside/laguna-s-2.1:free` (main_loop_rust.pl:36, main_loop_estree.pl:78),
# and the live process table confirms the colon form is what runs. An earlier
# version of this file asserted the HYPHEN form
# (`poolside/laguna-s-2.1-free`) and matched on exact string equality, so
# `ai_fallback_for` returned undef for the model actually in use and the
# free-models-per-day fallback NEVER fired — the worker sat in pir's own
# infinite 429 retry (observed climbing to a 15360s backoff) while this module
# believed it had a fallback ready.
#
# So the id is compared NORMALISED, not literally: `:` and `-` in the
# `s-2.1:free` / `s-2.1-free` tail are treated as the same model, and
# `WORKER_LAGUNA_MODEL` can still override it. Defined once so the loops cannot
# disagree about what "the Laguna model" is.
our $LAGUNA_MODEL = $ENV{WORKER_LAGUNA_MODEL} // 'poolside/laguna-s-2.1:free';

# OpenRouter ids are `vendor/model:variant`; the variant separator is a colon.
# Callers sometimes carry the hyphen variant, so normalise the variant
# separator before comparing identity. Everything before the last colon is the
# vendor/model and must still match exactly.
sub _norm_model {
    my ($m) = @_;
    return undef unless defined $m && length $m;
    my ($base, $variant) = $m =~ /^(.*?):([^:]*)$/ ? ($1, $2) : ($m, undef);
    $variant = '-' . $variant if defined $variant;
    return $base . (defined $variant ? $variant : '');
}

# Ollama Cloud may be metered — this is the one intentional cost. Empty disables.
our $FALLBACK_MODEL = exists $ENV{WORKER_FALLBACK_MODEL}
    ? $ENV{WORKER_FALLBACK_MODEL}
    : 'ollama-cloud/deepseek-v4.1-flash';

# ai_fallback_for($model) — the configured fallback for a model, or undef.
# Only Laguna has one; every other model (including Space Bunny Alpha) has no
# quota fallback at all, so a transient 429 there keeps its normal infinite retry.
sub ai_fallback_for {
    my ($model) = @_;
    return undef unless defined $model;
    # Compare NORMALISED, so the colon form the workers actually run still
    # matches a hyphen-configured Laguna id (and vice versa). An exact-string
    # comparison is what silently disabled this whole fallback once.
    return undef unless _norm_model($model) eq _norm_model($LAGUNA_MODEL);
    return undef unless defined $FALLBACK_MODEL && $FALLBACK_MODEL ne '';
    return undef if _norm_model($FALLBACK_MODEL) eq _norm_model($model);  # never fall back to itself
    return $FALLBACK_MODEL;
}

# quota_marker($text) — the matched line when the output shows Laguna's exact
# daily-quota error, else undef.
#
# Both conditions are required:
#   * the model is exactly Laguna (checked by the caller via ai_fallback_for),
#   * the text carries OpenRouter's quota code.
# A near-miss (plain 429, weekly usage limit, billing/quota, timeout, 5xx) does
# not contain the code and is therefore not matched — those keep retrying.
sub quota_marker {
    my ($text) = @_;
    return undef unless defined $text;
    for my $line (split /\n/, $text) {
        return $line if index($line, $QUOTA_MARKER) >= 0;
    }
    return undef;
}

# QuotaSwitch — one-way, bounded state for a single worker loop process.
#
#   my $sw = ai_fallback::QuotaSwitch->new($model);
#   if (my $fb = $sw->fallback_for($model)) { ... }
#   $sw->switch_to;              # one-way; a second call is a no-op
#   $sw->model;                  # current model
#
# The switch is one-way ON PURPOSE: switching back and forth between two models
# on the same error would never converge. A restarted worker probes Laguna again
# and re-switches if the daily quota is still exhausted, which is also how the
# switch is eventually undone — when quota resets.
package ai_fallback::QuotaSwitch;

use strict;
use warnings;

sub new {
    my ($class, $model) = @_;
    my $self = {
        model      => $model,
        switched   => 0,
        from       => undef,
        blocked_s  => 0,
    };
    return bless $self, $class;
}

sub model     { return $_[0]->{model} }
sub switched  { return $_[0]->{switched} }
sub from      { return $_[0]->{from} }

sub fallback_for {
    my ($self, $model) = @_;
    return ai_fallback::ai_fallback_for($model);
}

# switch_to($log_fh) — flip to the fallback once, logging one line so the stall
# becomes measurable instead of invisible. Returns the new model.
sub switch_to {
    my ($self, $log_fh) = @_;
    return $self->{model} if $self->{switched};
    my $fb = ai_fallback::ai_fallback_for($self->{model});
    return $self->{model} unless defined $fb;   # nothing to fall back to
    $self->{from}     = $self->{model};
    $self->{model}    = $fb;
    $self->{switched} = 1;
    if ($log_fh) {
        printf {$log_fh} "[%s] quota: %s hit OpenRouter %s — switching to %s\n",
            scalar(localtime), $self->{from}, $QUOTA_MARKER, $fb;
        $log_fh->flush if $log_fh->can('flush');
    }
    return $fb;
}

# blocked_seconds($secs) — remember how long the model was stalled, so the
# switch line can report the cost of the stall.
sub blocked_seconds {
    my ($self, $secs) = @_;
    $self->{blocked_s} = $secs if defined $secs;
    return $self->{blocked_s};
}

1;
