INSERT INTO user_behavior_hopping_out
SELECT
  window_start,
  window_end,
  COUNT(*) AS buy_cnt
FROM TABLE(
  HOP(TABLE user_behavior, DESCRIPTOR(ts), INTERVAL '10' SECOND, INTERVAL '30' SECOND)
)
WHERE behavior = 'buy'
GROUP BY window_start, window_end;
