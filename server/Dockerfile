FROM python:3.12-slim@sha256:a6e34c598f2467ed0e9a8d349809fcd8b5c603269512df273a0bb1784edc11b1
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app
COPY server/requirements-deploy.txt /app/server/requirements-deploy.txt
COPY server/wheels /wheels
RUN pip install --no-cache-dir --no-index --find-links=/wheels --require-hashes -r server/requirements-deploy.txt \
    && groupadd --gid 10001 dominion \
    && useradd --uid 10001 --gid dominion --no-create-home dominion \
    && mkdir /data && chown dominion:dominion /data
COPY --chown=10001:10001 server /app/server
USER 10001:10001
EXPOSE 8765
CMD ["python", "-m", "server.deployment"]
