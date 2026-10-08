"""Read-only historical PvP rivalry records derived from settled server matches."""
def rivalry_history(store, faction_id, limit=20):
    matches = store.execute(
        """SELECT m.id,m.faction_a,m.faction_b,m.score_a,m.score_b,
                  m.rounds_a,m.rounds_b,m.winner_id,m.created_at,
                  l.reason AS settlement_reason
           FROM pvp_matches m JOIN pvp_ledger l
             ON l.match_id=m.id AND l.faction_id=?
           WHERE m.status='complete' AND (m.faction_a=? OR m.faction_b=?)
           ORDER BY m.created_at DESC,m.rowid DESC LIMIT ?""",
        (faction_id,faction_id,faction_id,limit)
    ).fetchall()
    history = []
    for m in matches:
        a = m["faction_a"] == faction_id
        opponent_id = m["faction_b"] if a else m["faction_a"]
        opponent = store.execute(
            """SELECT f.name,f.tag,COALESCE(i.emblem,'shield') AS emblem,
                      COALESCE(i.banner,'obsidian') AS banner
               FROM factions f LEFT JOIN faction_identity i ON i.faction_id=f.id
               WHERE f.id=?""",(opponent_id,)
        ).fetchone()
        timed_out = m["settlement_reason"] == "pvp_timeout"
        result = "TIMEOUT" if timed_out else (
            "DRAW" if not m["winner_id"] else ("VICTORY" if m["winner_id"] == faction_id else "DEFEAT")
        )
        history.append({"match_id":m["id"],"opponent_id":opponent_id,
                        "opponent_name":opponent["name"],"opponent_tag":opponent["tag"],
                        "opponent_emblem":opponent["emblem"],"opponent_banner":opponent["banner"],
                        "our_score":m["score_a"] if a else m["score_b"],
                        "enemy_score":m["score_b"] if a else m["score_a"],
                        "our_attacks":m["rounds_a"] if a else m["rounds_b"],
                        "enemy_attacks":m["rounds_b"] if a else m["rounds_a"],
                        "result":result,"started_at":m["created_at"]})
    rivals = {}
    for m in history:
        rid = m["opponent_id"]
        if rid not in rivals:
            rivals[rid] = {"opponent_id":rid,"name":m["opponent_name"],"tag":m["opponent_tag"],
                           "emblem":m["opponent_emblem"],"banner":m["opponent_banner"],
                           "played":0,"wins":0,"losses":0,"draws":0,"timeouts":0}
        row = rivals[rid]
        row["played"] += 1
        result_key = {"VICTORY":"wins","DEFEAT":"losses","DRAW":"draws","TIMEOUT":"timeouts"}[m["result"]]
        row[result_key] += 1
    return {"matches":history,"rivals":sorted(rivals.values(),key=lambda x:(-x["played"],x["name"],x["opponent_id"])),
            "limit":limit,"authoritative":True,"cosmetic_only":True}


def trophy_case(store, faction_id):
    """Compute all-time prestige from settled battles, never from client claims."""
    rows = store.execute(
        """SELECT m.id,m.faction_a,m.faction_b,m.winner_id,m.created_at,
                  l.reason,c.id AS challenge_id
           FROM pvp_matches m
           JOIN pvp_ledger l ON l.match_id=m.id AND l.faction_id=?
           LEFT JOIN pvp_challenges c ON c.match_id=m.id AND c.status='accepted'
           WHERE m.status='complete' AND (m.faction_a=? OR m.faction_b=?)
           ORDER BY m.created_at ASC,m.rowid ASC""",
        (faction_id,faction_id,faction_id)
    ).fetchall()
    current=0
    best=0
    trophies=[]
    results={"wins":0,"losses":0,"draws":0,"timeouts":0}
    for m in rows:
        if m["reason"]=="pvp_timeout":
            outcome="timeouts"
        elif not m["winner_id"]:
            outcome="draws"
        elif m["winner_id"]==faction_id:
            outcome="wins"
        else:
            outcome="losses"
        results[outcome]+=1
        current=current+1 if outcome=="wins" else 0
        best=max(best,current)
        if outcome=="wins" and m["challenge_id"]:
            opponent_id=m["faction_b"] if m["faction_a"]==faction_id else m["faction_a"]
            opponent=store.execute("SELECT name,tag FROM factions WHERE id=?",(opponent_id,)).fetchone()
            trophies.append({"match_id":m["id"],"challenge_id":m["challenge_id"],
                             "opponent_id":opponent_id,"opponent_name":opponent["name"],
                             "opponent_tag":opponent["tag"],"trophy":"RIVAL_CONQUEROR"})
    return {"record":results,"current_win_streak":current,"best_win_streak":best,
            "rematch_trophies":list(reversed(trophies))[:30],
            "total_rematch_trophies":len(trophies),
            "cosmetic_only":True,"authoritative":True}
