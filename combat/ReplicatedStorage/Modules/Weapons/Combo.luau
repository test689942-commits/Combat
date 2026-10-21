--// Combo \\--

local Combo = {}

function Combo.CreateBuilder(settings)
	return function(data)
		local speed = data.Speed
		local impact = data.Impact / speed
		local actionTime

		if data.Length then
			actionTime = math.max(data.Length / speed, impact + settings.MinActionPadding)
		else
			actionTime = impact + settings.ActionPadding
		end

		local cooldown = impact + data.Recovery

		if settings.MinCooldownRatio then
			cooldown = math.max(cooldown, actionTime * settings.MinCooldownRatio)
		end

		return table.freeze({
			Damage = data.Damage;
			Stun = data.Stun;
			Speed = speed;
			HitboxDelay = math.max(0.05, impact - settings.HitLead);
			ImpactTime = impact;
			ActionTime = actionTime;
			Cooldown = cooldown;
			TrailStart = math.max(0, (data.Impact - settings.TrailLead) / speed);
			TrailEnd = impact + settings.TrailTail / speed;
			SwingSounds = data.SwingSounds;
			SwingSoundTime = math.max(0, impact - settings.SwingSoundLead);
			HitSounds = data.HitSounds;
			HitEffect = data.HitEffect;
			CritEffect = data.CritEffect;
			Knockback = data.Knockback;
			Lunge = data.Lunge;
			WalkSpeed = settings.WalkSpeed;
			Shake = data.Shake;
			HitStop = data.HitStop;
			FovKick = data.FovKick;
			Shockwave = data.Shockwave;
		})
	end
end

return Combo
