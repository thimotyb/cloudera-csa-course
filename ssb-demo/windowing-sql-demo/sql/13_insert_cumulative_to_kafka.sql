INSERT INTO user_behavior_cumulative_out
SELECT
  window_start,
  window_end,
  COUNT(*) AS buy_cnt
FROM TABLE(
  CUMULATE(TABLE user_behavior, DESCRIPTOR(ts), INTERVAL '10' SECOND, INTERVAL '1' MINUTE)
)
WHERE behavior = 'buy'
GROUP BY window_start, window_end;
