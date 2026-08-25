# Multi-transform interaction: native $((…)) lowering lost with 3+ done/ transforms

`i=0; j=0; j=$(( $j*$i ))` inside a loop lowers NATIVELY (no sh2.arith)
when text_ops runs alone, but keeps the runtime evaluator when
copy-propagation + dead-store-elim + merge-init-assignments are ALL
registered alongside (any two of the three restored native lowering;
each single drop did not).

Behavior stays correct either way (corpus estree 551/551 both configs);
the cost is the runtime evaluator on this shape. Suspected mechanism:
the trio's rewrites cascade until the provably-set analysis cannot prove
j/i assigned, so the estree native-$ref-arith gate refuses.

Follow-up: per-transform provenance for "provably set" facts, or a
joint gate. Filed by the text-ops/streaming goal increment.
