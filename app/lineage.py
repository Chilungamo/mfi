"""The AL-MFI lineage, from SOURCE through to INSIGHT."""

from enum import StrEnum


class Stage(StrEnum):
    SOURCE = "source"
    DOCUMENT = "document"
    OBSERVATION = "observation"
    FACT = "fact"
    FEATURE = "feature"
    INFERENCE = "inference"
    INDEX = "index"
    INSIGHT = "insight"


LINEAGE: tuple[Stage, ...] = tuple(Stage)


def can_derive(upstream: Stage, downstream: Stage) -> bool:
    """True when `downstream` is strictly later in the lineage than `upstream`."""
    return LINEAGE.index(upstream) < LINEAGE.index(downstream)
