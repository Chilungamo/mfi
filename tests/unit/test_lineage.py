from app.lineage import LINEAGE, Stage, can_derive


def test_lineage_order() -> None:
    assert [s.value for s in LINEAGE] == [
        "source",
        "document",
        "observation",
        "fact",
        "feature",
        "inference",
        "index",
        "insight",
    ]


def test_can_derive_is_forward_only() -> None:
    assert can_derive(Stage.OBSERVATION, Stage.FACT)
    assert not can_derive(Stage.FACT, Stage.OBSERVATION)
    assert not can_derive(Stage.FACT, Stage.FACT)
