Small example programs, each with a simple pedagogical goal.

They also help to validate SubX instruction semantics against native x86
hardware. For example, loading a single byte to a register would for some time
clear the rest of the register. This behavior was internally consistent with
unit tests. It took running an example binary natively to catch the discrepancy.
