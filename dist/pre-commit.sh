#!/bin/bash
make all
# Escape    Meaning
# -------   ------------------------------------------------------------
# %c        Column number where the violation occurred
# %d        Full diagnostic discussion of the violation
# %e        Explanation of violation or page numbers in PBP
# %F        Just the name of the file where the violation occurred.
# %f        Path to the file where the violation occurred.
# %l        Line number where the violation occurred
# %m        Brief description of the violation
# %P        Full name of the Policy module that created the violation
# %p        Name of the Policy without the Perl::Critic::Policy:: prefix
# %r        The string of source code that caused the violation
# %C        The class of the PPI::Element that caused the violation
# %s        The severity level of the violation
perlcritic --severity 3 \
    --verbose "%s %f:%l %P: %r\n" \
    --color-severity-2 'magenta' \
    --color-severity-3 'cyan' \
    --color-severity-4 'yellow' \
    --color-severity-5 'red' \
    --color src/lib
