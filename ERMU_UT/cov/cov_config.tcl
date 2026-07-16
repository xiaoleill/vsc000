# =============================================================================
#  IMC Coverage Configuration for ERMU
#  Enables line, toggle, and condition coverage for xrun
# =============================================================================

# Line coverage
coverage -line all

# Toggle coverage
coverage -toggle all

# Condition coverage
coverage -condition all

# FSM coverage (if applicable)
coverage -fsm all

# Coverage goals
# Line:     >= 95%
# Toggle:   >= 90%
# Condition: >= 95%
