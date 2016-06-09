"""Setup for Londiste.
"""

from setuptools import setup

setup(
    name = "londiste",
    description = "Database replication based on PgQ",
    url = "https://github.com/pgq/londiste",
    license = "ISC",
    version = '3.3',
    maintainer = "Marko Kreen",
    maintainer_email = "markokr@gmail.com",
    packages = ['londiste', 'londiste.handlers'],
    install_requires = ['pgq', 'skytools', 'psycopg2'],
    scripts = ['londiste.py'],
    entry_points = {
        'console_scripts': [
            'londiste = londiste.cli:main',
        ],
    },
    classifiers = [
        "Development Status :: 5 - Production/Stable",
        "Environment :: Console",
        "Environment :: No Input/Output (Daemon)",
        "Intended Audience :: System Administrators",
        "License :: OSI Approved :: ISC License (ISCL)",
        "Operating System :: POSIX",
        "Programming Language :: Python :: 2",
        "Programming Language :: Python :: 2.7",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.5",
        "Programming Language :: Python :: 3.6",
        "Topic :: Database",
        "Topic :: System :: Clustering",
        "Topic :: Utilities",
    ]
)

