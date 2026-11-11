VerificationTest[
    1 / 0,
    ComplexInfinity,
    TestID -> "TestFile2-Division"
]

VerificationTest[
    1 / 0,
    ComplexInfinity,
    { Power::infy },
    TestID -> "TestFile2-Division-Error"
]

VerificationTest[
    Pause[ 2 ],
    Null,
    TimeConstraint -> Quantity[ 0.1, "Seconds" ],
    TestID         -> "TestFile2-Pause"
]

VerificationTest[
    x,
    y,
    SameTest -> Equal,
    TestID   -> "TestFile2-Equal"
]

VerificationTest[
    Print[ "Hello, world!" ],
    Null,
    TestID -> "TestFile2-Print"
]