all: setup_py setup_coveralls setup_js setup_django

ci: setup_ci all

staging: create-staging update-staging

define resetdb_to_backup
	dropdb $1
	createdb $1
	pg_restore -O -x -n public -d $1 ~hacklab/sql-backup/last.psqlc
endef

define reset_media
	rm -rf ~/webfiles/media/
	cp -r ~timtec-production/webfiles/media ~/webfiles/
endef

define base_update
	cp timtec/settings_local_$1.py timtec/settings_local.py
	~/env/bin/pip install -r requirements.txt
	~/env/bin/python manage.py syncdb --noinput
	~/env/bin/python manage.py migrate --noinput
	~/env/bin/python manage.py collectstatic --noinput
	~/env/bin/python manage.py compilemessages
	touch ~/wsgi-reload
endef

create-staging:
	virtualenv ~/env
	~/env/bin/pip install -r requirements.txt
	mkdir -p ~/webfiles/static
	mkdir -p ~/webfiles/media

create-production: create-staging
	cp timtec/settings_local_production.py timtec/settings_local.py
	cp ../settings_production.py timtec/settings_production.py
	~/env/bin/python manage.py syncdb --noinput --no-initial-data
	~/env/bin/python manage.py migrate --noinput --no-initial-data
	~/env/bin/python manage.py loaddata production
	~/env/bin/python manage.py collectstatic --noinput
	~/env/bin/python manage.py compilemessages
	~/env/bin/python manage.py create_student_and_professor
	touch ~/wsgi-reload

update-test:
	$(call resetdb_to_backup,timtec-test)
	$(call reset_media)
	$(call base_update,test)

update-dev:
	$(call resetdb_to_backup,timtec-dev)
	$(call reset_media)
	$(call base_update,timtec_dev)

update-staging:
	$(call resetdb_to_backup,timtec-staging)
	$(call reset_media)
	$(call base_update,staging)

update-design:
	$(call base_update,design)

update-production:
	cp ../settings_production.py timtec/settings_production.py
	$(call base_update,production)

test_collectstatic: clean
	python manage.py collectstatic --noinput -n

clean:
	find . -type f -name '*.py[co]' -exec rm {} \;

python_tests: clean
	py.test --pep8 --flakes --tb=native --reuse-db --cov . . $*

js_tests:
	find . -path ./bower_components -prune -o -path bower_components/ -prune -o -path ./node_modules -prune -o -regex ".*/vendor/.*" -prune -o -name '*.js' -exec jshint {} \;

karma_tests:
	karma start confkarma.js $*

all_tests: clean test_collectstatic python_tests karma_tests js_tests

setup_ci:
	psql -c 'create database timtec_ci;' -U postgres
	cp timtec/settings_local_ci.py timtec/settings_local.py

setup_py:
	pip install -q -r requirements.txt
	pip install -q -r dev-requirements.txt
	python setup.py -q develop

setup_coveralls:
	pip install -q coveralls

setup_js:
	sudo `which npm` -g install less yuglify karma karma-cli karma-phantomjs-launcher karma-jasmine jshint ngmin grunt-cli --loglevel silent
	sudo npm install grunt grunt-angular-gettext

setup_django: clean
	python manage.py syncdb --all --noinput
	python manage.py compilemessages

dumpdata: clean
	python manage.py dumpdata --indent=2 -n -e south.migrationhistory -e admin.logentry -e socialaccount.socialaccount -e socialaccount.socialapp -e sessions.session -e contenttypes.contenttype -e auth.permission -e account.emailconfirmation -e socialaccount.socialtoken

reset_db: clean
	python manage.py reset_db --router=default --noinput -U $(USER)
	python manage.py syncdb --all --noinput
	python manage.py migrate --noinput --fake

messages: clean
	python manage.py makemessages -a -d django
