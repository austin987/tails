/***************************************************************************
Name: CS Lite
Description: Control cookie permissions.
Author: Ron Beckman
Homepage: http://addons.mozilla.org

Copyright (C) 2007  Ron Beckman

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to:

Free Software Foundation, Inc.
51 Franklin Street
Fifth Floor
Boston, MA  02110-1301
USA
***************************************************************************/


const COOKIESAFE_CONTRACTID = '@mozilla.org/CookieSafe;1';
const COOKIESAFE_CID = Components.ID('{d3b60080-fd35-4507-a5a2-70c3560b3874}');
const COOKIESAFE_IID = Components.interfaces.nsICookieSafe;
const COOKIESAFE_SERVICENAME = 'CookieSafe';

var nsCookieSafe = {

	removeSub: function(host) {
		if (!host || host.indexOf('.')==-1) return host;

		//remove port number if found
		host = host.replace(/\:.*$/g,'');

		var testip = host.replace(/\./g,'');
		if (!isNaN(testip)) return host;

		var domain = host.split('.');
		if (domain.length<3) return domain.join('.');

		try {
			var sld = domain[domain.length-2];
			var ext = domain[domain.length-1];
			if ((sld in this && this[sld].indexOf(' '+ext+' ')!=-1) ||
			    (sld=='co' || sld=='com' || sld=='org')) {
				return domain[domain.length-3]+'.'+domain[domain.length-2]+'.'+domain[domain.length-1];
			} else {
				return domain[domain.length-2]+'.'+domain[domain.length-1];
			}
		} catch(e) {
			return domain[domain.length-2]+'.'+domain[domain.length-1];
		}
	},

	formatCookieString: function(ckstr,uri) {
		var url = uri.QueryInterface(Components.interfaces.nsIURL);

		//setup cookie object to appear as nsICookie
		var cookie = {
			name:     null,
			value:    null,
			isDomain: false,
			host:     uri.host,
			path:     url.directory,
			isSecure: false,
			expires:  0
		};

		var dt = new Date();
		var time = dt.getTime();

		ckstr = ckstr.replace(/\; /g,'\;');
		var values = ckstr.split('\;');

		for (var i=0; i<values.length; ++i) {
			if (values[i].substr(0,6).toLowerCase()=='domain') {
				cookie.host = values[i].substr(values[i].indexOf('=')+1);
			}
			if (values[i].substr(0,4).toLowerCase()=='path') {
				cookie.path = values[i].substr(values[i].indexOf('=')+1);
			}
			if (values[i].substr(0,7).toLowerCase()=='expires') {
				var expStr = values[i].substr(values[i].indexOf('=')+1);
				expStr = expStr.replace(/\-/g,' ');
				var exp = parseInt(Date.parse(expStr));
				cookie.expires = (exp < time) ? 0 : exp / 1000;
			}
			if (values[i].substr(0,6).toLowerCase()=='secure') {
				cookie.isSecure = true;
			}
		}

		cookie.name = values[0].substr(0,values[0].indexOf('='));
		cookie.value = values[0].substr(values[0].indexOf('=')+1);
		if (cookie.host.charAt(0)=='.') cookie.isDomain = true;

		return cookie;
	},

	/** BEGIN ORGANIZATIONAL SECOND LEVEL DOMAINS **/
	ab: ' ca ', 
	ac: ' ac at be cn id il in jp kr nz th uk za ',
	ad: ' jp ',
	adm: ' br ',
	adv: ' br ',
	agro: ' pl ',
	ah: ' cn ',
	aid: ' pl ',
	alt: ' za ',
	am: ' br ',
	ar: ' com ',
	arq: ' br ',
	art: ' br ',
	arts: ' ro ',
	asn: ' au ',
	asso: ' fr mc ',
	atm: ' pl ',
	auto: ' pl ',
	bbs: ' tr ',
	bc: ' ca ',
	bio: ' br ',
	biz: ' pl ',
	bj: ' cn ',
	br: ' com ',
	cn: ' com ',
	cng: ' br ',
	cnt: ' br ',
	co: ' ac at bw ck cr id il im in je jp ke kr ls ma nz th ug uk uz ve vi za zm zw ',
	com: ' af ag ar au bd bh bn bo br bz cn co cu do ec eg et fj fr gi gt hk jm kh ly mm mt mx my na nf ng ni np om pa pe ph pk pl pr py qa ro ru sa sb sg sv tj tr tw ua uy vc vn ',
	cq: ' cn ',
	cri: ' nz ',
	ecn: ' br ',
	ed: ' jp ',
	edu: ' ar au cn hk mm mx pl tr za ',
	eng: ' br ',
	esp: ' br ',
	etc: ' br ',
	eti: ' br ',
	eu: ' com lv ',
	fin: ' ec ',
	firm: ' ro ',
	fm: ' br ',
	fot: ' br ',
	fst: ' br ',
	g12: ' br ',
	gb: ' com net ',
	gd: ' cn ',
	gen: ' nz ',
	gmina: ' pl ',
	go: ' jp kr th ',
	gob: ' mx ',
	gov: ' ar br cn ec il in mm mx sg tr uk za ',
	govt: ' nz ',
	gr: ' jp ',
	gs: ' cn ',
	gsm: ' pl ',
	gv: ' ac at ',
	gx: ' cn ',
	gz: ' cn ',
	hb: ' cn ',
	he: ' cn ',
	hi: ' cn ',
	hk: ' cn ',
	hl: ' cn ',
	hn: ' cn ',
	hu: ' com ',
	id: ' au ',
	ind: ' br ',
	inf: ' br ',
	info: ' pl ro ',
	iwi: ' nz ',
	jl: ' cn ',
	jor: ' br ',
	js: ' cn ',
	k12: ' il tr ',
	lel: ' br ',
	lg: ' jp ',
	ln: ' cn ',
	ltd: ' uk ',
	mail: ' pl ',
	maori: ' nz ',
	mb: ' ca ',
	me: ' uk ',
	med: ' br ec ',
	media: ' pl ',
	mi: ' th ',
	miasta: ' pl ',
	mil: ' br ec nz pl tr za ',
	mo: ' cn ',
	muni: ' il ',
	nb: ' ca ',
	ne: ' jp kr ',
	net: ' ar au br cn ec hk id il in mm mx nz pl ru sg th tr tw za ',
	nf: ' ca ',
	ngo: ' za ',
	nm: ' cn kr ',
	no: ' com ',
	nom: ' br pl ro za ',
	ns: ' ca ',
	nt: ' ca ro ',
	ntr: ' br ',
	nx: ' cn ',
	odo: ' br ',
	off: ' ai ',
	on: ' ca ',
	or: ' ac at jp kr th ',
	org: ' ar au br cn ec hk il in mm mx nz pl ro ru sg tr tw uk za ',
	pc: ' pl ',
	pe: ' ca ',
	plc: ' uk ',
	ppg: ' br ',
	presse: ' fr ',
	priv: ' pl ',
	pro: ' br ',
	psc: ' br ',
	psi: ' br ',
	qc: ' ca com ',
	qh: ' cn ',
	re: ' kr ',
	realestate: ' pl ',
	rec: ' br ro ',
	rel: ' pl ',
	sa: ' com ',
	sc: ' cn ',
	school: ' nz za ',
	se: ' com net ',
	sh: ' cn ',
	shop: ' pl ',
	sk: ' ca ',
	sklep: ' pl ',
	slg: ' br ',
	sn: ' cn ',
	sos: ' pl ',
	store: ' ro ',
	targi: ' pl ',
	tj: ' cn ',
	tm: ' fr mc pl ro za ',
	tmp: ' br ',
	tourism: ' pl ',
	travel: ' pl ',
	tur: ' br ',
	turystyka: ' pl ',
	tv: ' br ',
	tw: ' cn ',
	uk: ' co com net ',
	us: ' com ca ',
	uy: ' com ',
	vet: ' br ',
	web: ' za ',
	www: ' ro ',
	xj: ' cn ',
	xz: ' cn ',
	yk: ' ca ',
	yn: ' cn ',
	za: ' com ',
	zj: ' cn ', 
	zlg: ' br ',
	/** END ORGANIZATIONAL SECOND LEVEL DOMAINS **/

	QueryInterface: function(iid) {
		if (!iid.equals(Components.interfaces.nsISupports) &&
		    !iid.equals(COOKIESAFE_IID))
			throw Components.results.NS_ERROR_NO_INTERFACE;
		return this;
	}
};

var nsCookieSafeModule = {

	registerSelf: function(compMgr, fileSpec, location, type) {
		compMgr = compMgr.QueryInterface(Components.interfaces.nsIComponentRegistrar);
		compMgr.registerFactoryLocation(COOKIESAFE_CID,
						COOKIESAFE_SERVICENAME,
						COOKIESAFE_CONTRACTID,
						fileSpec,location,type);
	},

	unregisterSelf: function (compMgr, fileSpec, location) {
		compMgr = compMgr.QueryInterface(Components.interfaces.nsIComponentRegistrar);
		compMgr.unregisterFactoryLocation(COOKIESAFE_CID,fileSpec);
	},

	getClassObject: function(compMgr, cid, iid) {
		if (!cid.equals(COOKIESAFE_CID))
			throw Components.results.NS_ERROR_NO_INTERFACE;
		if (!iid.equals(Components.interfaces.nsIFactory))
			throw Components.results.NS_ERROR_NOT_IMPLEMENTED;
		return this.nsCookieSafeFactory;
	},

	canUnload: function(compMgr) {
		return true;
	},

	nsCookieSafeFactory: {

		createInstance: function(outer, iid) {
			if (outer != null)
				throw Components.results.NS_ERROR_NO_AGGREGATION;
			if (!iid.equals(COOKIESAFE_IID) &&
			    !iid.equals(Components.interfaces.nsISupports))
				throw Components.results.NS_ERROR_INVALID_ARG;
			return nsCookieSafe;
		}
	}
};

function NSGetModule(comMgr, fileSpec) { return nsCookieSafeModule; }
