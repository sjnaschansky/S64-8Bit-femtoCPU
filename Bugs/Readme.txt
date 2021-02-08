Bugs

As soon as I posted this project on the github, I found one error.
The carry flag is set incorrectly when working with negative numbers.

The error is here:
ExtendedALU := ('0' & Acc) + ('0' & InputBuffer);
ExtendedALU := ('0' & Acc) - ('0' & InputBuffer);


