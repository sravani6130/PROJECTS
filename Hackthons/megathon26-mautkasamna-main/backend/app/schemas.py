"""Request bodies. Strict: unknown fields are rejected and every value is
bounded, so a client cannot store arbitrary data (or extra personal data)
on the server.

The progress report (schema_version 1) mirrors what the Gullak app tracks
locally: chapter completion and stars (`mission_progress`), badges
(`badge_award`), the current chapter (`story_save`) and categorical outcomes
of the story's key decisions. It deliberately has no money balances, names,
device details or raw decision logs.
"""

from __future__ import annotations

from datetime import datetime
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

CODE_PATTERN = r"^[A-Z0-9]{2,10}(-[A-Z0-9]{2,10}){1,3}$"
STUDENT_ID_PATTERN = r"^STU-[0-9A-Z]{4}-[0-9A-Z]{4}$"
CHAPTER_IDS = ("C1", "C2", "C3", "C4", "C5", "C6", "C7")


class Strict(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)


def normalise_code(value: str) -> str:
    return value.strip().upper().replace(" ", "")


class CodeCheck(Strict):
    code: Annotated[str, Field(min_length=3, max_length=40)]

    @field_validator("code")
    @classmethod
    def _norm(cls, v: str) -> str:
        return normalise_code(v)


class Registration(CodeCheck):
    # 128-bit random value from the app, hex or base64url.
    registration_key: Annotated[str, Field(min_length=22, max_length=64, pattern=r"^[A-Za-z0-9_-]+$")]
    app_version: Annotated[str, Field(max_length=20, pattern=r"^[0-9A-Za-z.+-]*$")] = ""


class ChapterProgress(Strict):
    id: Literal["C1", "C2", "C3", "C4", "C5", "C6", "C7"]
    completed: bool
    best_stars: Annotated[int, Field(ge=0, le=3)]
    plays: Annotated[int, Field(ge=0, le=10_000)]
    first_completed_at: datetime | None = None


class StoryPosition(Strict):
    current_chapter: Annotated[int, Field(ge=1, le=8)]
    finished: bool


class Indicators(Strict):
    """Outcomes of decisions in finished story chapters. Absent = not yet played."""

    c1_surprise_cost: Literal["own_money", "advance"] | None = None
    c2_goal: Literal["kit", "course", "laptop"] | None = None
    c2_weeks_saved: Annotated[int, Field(ge=0, le=4)] | None = None
    c3_pending_payment: Literal["verified", "paid_twice", "paid_cash"] | None = None
    c4_scams_handled_safely: Annotated[int, Field(ge=0, le=4)] | None = None
    c4_scams_followed: Annotated[int, Field(ge=0, le=4)] | None = None
    c4_hints_used: Annotated[int, Field(ge=0, le=1000)] | None = None
    c5_payment_method: Literal["debit", "cash", "credit", "waited"] | None = None
    c5_credit_repayment: Literal["full", "more_than_minimum", "minimum"] | None = None
    c6_fixed_deposit: bool | None = None
    c6_emergency_source: Literal["savings", "broke_deposit", "borrowed_family"] | None = None
    c7_claimed_excluded_cost: bool | None = None
    c7_policy_choice: Literal["keep", "addon", "drop"] | None = None
    c7_used_emergency_fund: bool | None = None


class ProgressReport(Strict):
    schema_version: Literal[1]
    student_id: Annotated[str, Field(pattern=STUDENT_ID_PATTERN)]
    revision: Annotated[int, Field(ge=1, le=1_000_000_000)]
    generated_at: datetime
    last_activity_at: datetime | None = None
    app_version: Annotated[str, Field(max_length=20, pattern=r"^[0-9A-Za-z.+-]*$")] = ""
    story: StoryPosition
    chapters: Annotated[list[ChapterProgress], Field(max_length=7)]
    badges: Annotated[list[Annotated[str, Field(pattern=r"^[a-z0-9_]{1,40}$")]], Field(max_length=20)]
    indicators: Indicators = Indicators()

    @model_validator(mode="after")
    def _consistent(self) -> "ProgressReport":
        ids = [c.id for c in self.chapters]
        if len(ids) != len(set(ids)):
            raise ValueError("each chapter may appear only once")
        if len(set(self.badges)) != len(self.badges):
            raise ValueError("badges must be unique")
        for c in self.chapters:
            if c.completed and c.best_stars < 1:
                raise ValueError(f"{c.id}: a completed chapter has 1-3 stars")
            if not c.completed and c.best_stars:
                raise ValueError(f"{c.id}: stars require completion")
        if self.story.finished != (self.story.current_chapter == 8):
            raise ValueError("finished story must be at chapter 8")
        return self

    @property
    def completed_chapters(self) -> list[ChapterProgress]:
        return [c for c in self.chapters if c.completed]


class Login(Strict):
    username: Annotated[str, Field(min_length=1, max_length=64)]
    password: Annotated[str, Field(min_length=1, max_length=200)]
