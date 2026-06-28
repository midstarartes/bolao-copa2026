-- Patch 033 - Corrige pontuacao de mata-mata com winner_team ausente
-- Contexto:
-- - Antes do ajuste de frontend, palpites normais eram salvos sem winner_team.
-- - Em mata-mata, app_prediction_result_hit dependia exclusivamente de winner_team.
-- - Para jogos sem empate no placar oficial, a direcao do placar permite inferir quem avancou.
-- - Para empate oficial, winner_team continua obrigatorio para saber quem avancou nos penaltis.

create or replace function public.app_prediction_result_hit(
  p_phase_label      text,
  p_phase            text,
  p_official_home    integer,
  p_official_away    integer,
  p_official_winner  text,
  p_predicted_home   integer,
  p_predicted_away   integer,
  p_predicted_winner text
)
returns boolean
language sql
immutable
as $$
  select
    case
      when p_official_home is null or p_official_away is null then false
      when public.app_phase_type(p_phase_label, p_phase) = 'group' then
           ((p_predicted_home - p_predicted_away) = 0 and (p_official_home - p_official_away) = 0)
        or ((p_predicted_home - p_predicted_away) > 0 and (p_official_home - p_official_away) > 0)
        or ((p_predicted_home - p_predicted_away) < 0 and (p_official_home - p_official_away) < 0)
      else
        (
          p_official_winner is not null
          and p_predicted_winner is not null
          and lower(trim(p_predicted_winner)) = lower(trim(p_official_winner))
        )
        or (
          p_official_home <> p_official_away
          and p_predicted_home <> p_predicted_away
          and (
               ((p_predicted_home - p_predicted_away) > 0 and (p_official_home - p_official_away) > 0)
            or ((p_predicted_home - p_predicted_away) < 0 and (p_official_home - p_official_away) < 0)
          )
        )
    end
$$;
