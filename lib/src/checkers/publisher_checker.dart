import 'dart:io';
import 'package:yaml/yaml.dart';
import '../models/check_result.dart';
import '../pub_api/pub_api_client.dart';
import 'checker.dart';

/// Checks the trustworthiness of package publishers.
///
/// - Reports packages with no verified publisher as info
/// - Reports packages whose publisher ID uses a disposable email domain as critical
class PublisherChecker implements Checker {
  final String projectPath;
  final PubApiClient apiClient;

  const PublisherChecker({
    required this.projectPath,
    required this.apiClient,
  });

  /// Known disposable email service domains.
  /// Subdomains (e.g. user.mailinator.com) are also detected by _isDisposableDomain.
  static const _disposableDomains = {
    'mailinator.com',
    'guerrillamail.com',
    'guerrillamail.net',
    'guerrillamail.org',
    'guerrillamail.de',
    'guerrillamail.biz',
    'guerrillamail.info',
    'sharklasers.com',
    'spam4.me',
    'tempmail.com',
    'temp-mail.org',
    'throwam.com',
    'yopmail.com',
    'yopmail.fr',
    'cool.fr.nf',
    'jetable.fr.nf',
    'nospam.ze.tc',
    'nomail.xl.cx',
    'mega.zik.dj',
    'speed.1s.fr',
    'courriel.fr.nf',
    'trashmail.com',
    'trashmail.me',
    'trashmail.net',
    'trashmail.at',
    'trashmail.io',
    '10minutemail.com',
    '10minutemail.net',
    'fakeinbox.com',
    'dispostable.com',
    'mailnull.com',
    'maildrop.cc',
    'discard.email',
    'spambox.us',
    'getairmail.com',
    'filzmail.com',
    'spamfree24.org',
    'spamex.com',
    'mailnesia.com',
    'mailforspam.com',
    'spamgourmet.com',
    'spamgourmet.net',
    'spamgourmet.org',
    'tempr.email',
    'cmail.club',
    'cmail.org',
    'anonbox.net',
    'anonymbox.com',
    'antispam24.de',
    'binkmail.com',
    'bobmail.info',
    'chammy.info',
    'deadaddress.com',
    'despam.it',
    'devnullmail.com',
    'dingbone.com',
    'dontsendmespam.de',
    'dump-email.info',
    'fakedemail.com',
    'fakemail.fr',
    'fastacura.com',
    'fastchevy.com',
    'fastchrysler.com',
    'fastkawasaki.com',
    'fastmazda.com',
    'fastmitsubishi.com',
    'fastnissan.com',
    'fastsubaru.com',
    'fastsuzuki.com',
    'fasttoyota.com',
    'fastyamaha.com',
    'forgetmail.com',
    'get1mail.com',
    'getonemail.net',
    'gishpuppy.com',
    'gowikibooks.com',
    'gowikicampus.com',
    'gowikicars.com',
    'gowikifilms.com',
    'gowikigames.com',
    'gowikimusic.com',
    'gowikinetwork.com',
    'gowikitravel.com',
    'gowikitv.com',
    'humaility.com',
    'ieatspam.eu',
    'ieatspam.info',
    'jetable.com',
    'jetable.net',
    'jetable.org',
    'kasmail.com',
    'kaspop.com',
    'killmail.com',
    'killmail.net',
    'klassmaster.com',
    'kulturbetrieb.info',
    'kurzepost.de',
    'letthemeatspam.com',
    'lol.ovpn.to',
    'lookugly.com',
    'lortemail.dk',
    'mail-temporaire.fr',
    'mail.by',
    'mail.mezimages.net',
    'mailbidon.com',
    'mailexpire.com',
    'mailfreeonline.com',
    'mailguard.me',
    'mailin8r.com',
    'mailinater.com',
    'mailismagic.com',
    'mailme.lv',
    'mailme24.com',
    'mailmetrash.com',
    'mailmoat.com',
    'mailnew.com',
    'mailpick.biz',
    'mailrock.biz',
    'mailscrap.com',
    'mailshell.com',
    'mailsiphon.com',
    'mailtemp.info',
    'mailtome.de',
    'mailtothis.com',
    'mailtrash.net',
    'mailzilla.com',
    'mailzilla.org',
    'mbx.cc',
    'meltmail.com',
    'messagebeamer.de',
    'mierdamail.com',
    'mintemail.com',
    'moburl.com',
    'moncourrier.fr.nf',
    'monemail.fr.nf',
    'monmail.fr.nf',
    'mt2009.com',
    'mt2014.com',
    'mytrashmail.com',
    'neomailbox.com',
    'nepwk.com',
    'nervmich.net',
    'nervtmich.net',
    'netmails.net',
    'neverbox.com',
    'noclickemail.com',
    'nogmailspam.info',
    'nomail2me.com',
    'nomorespamemails.com',
    'nospamfor.us',
    'nospamthanks.info',
    'notmailinator.com',
    'nowmymail.com',
    'objectmail.com',
    'obobbo.com',
    'odaymail.com',
    'oneoffemail.com',
    'ordinaryamerican.net',
    'owlpic.com',
    'pimpedupmyspace.com',
    'pjjkp.com',
    'plexolan.de',
    'poczta.onet.pl',
    'politikerclub.de',
    'poofy.org',
    'pookmail.com',
    'proxymail.eu',
    'prtnx.com',
    'putthisinyourspamdatabase.com',
    'qq.com',
    'quickinbox.com',
    'rcpt.at',
    'recode.me',
    'recursor.net',
    'regbypass.com',
    'regbypass.comsafe-mail.net',
    'rmqkr.net',
    'rppkn.com',
    'rtrtr.com',
    's0ny.net',
    'safe-mail.net',
    'safersignup.de',
    'safetymail.info',
    'safetypost.de',
    'sendspamhere.com',
    'sharedmailbox.org',
    'shiftmail.com',
    'sibmail.com',
    'skeefmail.com',
    'slopsbox.com',
    'smellfear.com',
    'snakemail.com',
    'sneakemail.com',
    'sofimail.com',
    'sofort-mail.de',
    'spam.la',
    'spam.su',
    'spamcon.org',
    'spamday.com',
    'spamfree.eu',
    'spamgob.com',
    'spamherelots.com',
    'spamhereplease.com',
    'spamhole.com',
    'spamify.com',
    'spamkill.info',
    'spaml.de',
    'spammotel.com',
    'spamoff.de',
    'spamslicer.com',
    'spamspot.com',
    'spamthis.co.uk',
    'spamtroll.net',
    'supergreatmail.com',
    'supermailer.jp',
    'suremail.info',
    'teewars.org',
    'teleworm.com',
    'teleworm.us',
    'tempalias.com',
    'tempinbox.co.uk',
    'tempinbox.com',
    'tempmail.eu',
    'tempomail.fr',
    'temporaryinbox.com',
    'tgasa.com',
    'thanksnospam.info',
    'thisisnotmyrealemail.com',
    'throwaway.email',
    'tilien.com',
    'tittbit.in',
    'tradermail.info',
    'trash-amil.com',
    'trash-mail.at',
    'trash-mail.cf',
    'trash-mail.ga',
    'trash-mail.gq',
    'trash-mail.ml',
    'trash-mail.tk',
    'trash2009.com',
    'trashemail.de',
    'trashmail.de',
    'trashmail.org',
    'trashmailer.com',
    'trashymail.com',
    'trbvm.com',
    'turual.com',
    'twinmail.de',
    'tyldd.com',
    'uggsrock.com',
    'uroid.com',
    'us.af',
    'veryrealemail.com',
    'viditag.com',
    'viewcastmedia.com',
    'viewcastmedia.net',
    'viewcastmedia.org',
    'wegwerfmail.de',
    'wegwerfmail.net',
    'wegwerfmail.org',
    'wetrainbayarea.com',
    'wetrainbayarea.org',
    'wh4f.org',
    'whyspam.me',
    'willhackforfood.biz',
    'willselfdestruct.com',
    'wuzupmail.net',
    'xagloo.com',
    'xemaps.com',
    'xents.com',
    'xmaily.com',
    'xoxy.net',
    'yep.it',
    'yogamaven.com',
    'yomail.info',
    'yopmail.net',
    'yourdomain.com',
    'ypmail.webarnak.fr.eu.org',
    'yuurok.com',
    'z1p.biz',
    'za.com',
    'zehnminuten.de',
    'zehnminutenmail.de',
    'zippymail.info',
    'zoemail.net',
    'zoemail.org',
    'zomg.info',
  };

  @override
  Future<List<CheckResult>> run() async {
    final lockFile = File('$projectPath/pubspec.lock');
    if (!lockFile.existsSync()) return [];

    final results = <CheckResult>[];
    final lockedVersions = _readLockFile(lockFile, results);
    if (lockedVersions.isEmpty) return results;

    for (final name in lockedVersions.keys) {
      try {
        final publisherId = await apiClient.fetchPublisher(name);

        if (publisherId == null) {
          results.add(CheckResult(
            package: name,
            severity: Severity.info,
            message: 'No verified publisher',
            detail: 'This package has no verified publisher on pub.dev. '
                'We recommend independently verifying the maintainer\'s identity.',
          ));
          continue;
        }

        if (_isDisposableDomain(publisherId)) {
          results.add(CheckResult(
            package: name,
            severity: Severity.critical,
            message:
                'Disposable email domain registered as publisher: $publisherId',
            detail:
                'A disposable email domain used in supply-chain attacks is registered '
                'as the publisher ID. Avoid using this package.',
          ));
        }
      } on PubApiException catch (e) {
        results.add(CheckResult(
          package: name,
          severity: Severity.warning,
          message: 'Failed to fetch publisher info',
          detail: e.message,
        ));
      }
    }
    return results;
  }

  /// Returns true if publisherId uses a disposable email domain.
  /// publisherId is normally a domain (e.g. dart.dev), but also handles
  /// email@domain format by extracting the part after @.
  /// Subdomains (e.g. user.mailinator.com) are also detected.
  bool _isDisposableDomain(String publisherId) {
    final lower = publisherId.toLowerCase();
    final domain = lower.contains('@') ? lower.split('@').last : lower;
    if (_disposableDomains.contains(domain)) return true;
    return _disposableDomains.any((d) => domain.endsWith('.$d'));
  }

  Map<String, String> _readLockFile(File lockFile, List<CheckResult> results) {
    try {
      return _parseLockFile(lockFile.readAsStringSync());
    } on YamlException catch (e) {
      results.add(CheckResult(
        package: '(project)',
        severity: Severity.warning,
        message: 'Failed to parse pubspec.lock',
        detail: 'Invalid YAML; some checks were skipped: ${e.message}',
      ));
    } on FileSystemException catch (e) {
      results.add(CheckResult(
        package: '(project)',
        severity: Severity.warning,
        message: 'Failed to read pubspec.lock',
        detail: e.message,
      ));
    }
    return {};
  }

  Map<String, String> _parseLockFile(String content) {
    final yaml = loadYaml(content);
    if (yaml is! YamlMap) return {};
    final packages = yaml['packages'];
    if (packages is! YamlMap) return {};

    final result = <String, String>{};
    for (final entry in packages.entries) {
      final name = entry.key as String;
      final meta = entry.value as YamlMap;
      if (meta['source'] == 'hosted') {
        final version = meta['version'] as String?;
        if (version != null) result[name] = version;
      }
    }
    return result;
  }
}
