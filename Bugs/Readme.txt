Bugs

As soon as this project was placed on the github, one error was founded.
The carry flag is set incorrectly when working with negative numbers.

The error is here:
ExtendedALU := ('0' & Acc) + ('0' & InputBuffer);
ExtendedALU := ('0' & Acc) - ('0' & InputBuffer);

Signed expansion should be used instead of zero expansion.

The correct variant is below:
ExtendedALU := SXT (Acc, CPUBits + 1) + SXT (InputBuffer, CPUBits + 1);
ExtendedALU := SXT (Acc, CPUBits + 1) - SXT (InputBuffer, CPUBits + 1);
