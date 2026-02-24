INSERT INTO user_behavior_tumbling_out
SELECT
  window_start,
  window_end,
  COUNT(*) AS buy_cnt
FROM TABLE(
  TUMBLE(TABLE user_behavior, DESCRIPTOR(ts), INTERVAL '30' SECOND)
)
WHERE behavior = 'buy'
GROUP BY window_start, window_end;
