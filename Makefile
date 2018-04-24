BUCKET = beer.aepps.com
REGION = eu-central-1
DOMAIN = beer.aepps.com
WORK_DIR = letsencrypt
EMAIL = aeternity@apeunit.com

certificate: $(WORK_DIR)
	letsencrypt --agree-tos -a letsencrypt-s3front:auth \
	  -i letsencrypt-s3front:installer \
	  --letsencrypt-s3front:auth-s3-bucket ${BUCKET} \
	  --letsencrypt-s3front:auth-s3-region ${REGION} \
	  --letsencrypt-s3front:installer-cf-distribution-id ${DISTRIBUTION_ID} \
	  -d ${DOMAIN} --work-dir ${WORK_DIR} --logs-dir ${WORK_DIR} --config-dir ${WORK_DIR} \
	  --email ${EMAIL} --non-interactive

$(WORK_DIR):
	@mkdir -p $@
