using Toybox.Lang;
using Toybox.Time;
using Toybox.Time.Gregorian;

//! POKE: VOTD — offline verse of the day (31 BSB verses, text copied from bundled BSB at
//! import time; no network). Picked by day of year. Available to the glance process.
(:glance)
module Votd {
    const REFS = [
        "JHN 3:16",
        "PSA 23:1",
        "ROM 8:28",
        "PHP 4:13",
        "JER 29:11",
        "PRO 3:5",
        "ISA 40:31",
        "MAT 11:28",
        "PSA 46:1",
        "JOS 1:9",
        "ROM 12:2",
        "GAL 2:20",
        "EPH 2:8",
        "2CO 5:17",
        "HEB 11:1",
        "1JN 1:9",
        "PSA 119:105",
        "MAT 6:33",
        "JHN 14:6",
        "ROM 5:8",
        "PHP 4:6",
        "1PE 5:7",
        "LAM 3:23",
        "PSA 37:4",
        "ISA 41:10",
        "MIC 6:8",
        "COL 3:23",
        "HEB 12:1",
        "JAS 1:5",
        "REV 21:4",
        "GEN 1:1",
    ];
    const TEXTS = [
        "For God so loved the world that He gave His one and only Son, that everyone who believes in Him shall not perish but have eternal life.",
        "A Psalm of David. The LORD is my shepherd; I shall not want.",
        "And we know that God works all things together for the good of those who love Him, who are called according to His purpose.",
        "I can do all things through Christ who gives me strength.",
        "For I know the plans I have for you, declares the LORD, plans to prosper you and not to harm you, to give you a future and a hope.",
        "Trust in the LORD with all your heart, and lean not on your own understanding;",
        "But those who wait upon the LORD will renew their strength; they will mount up with wings like eagles; they will run and not grow weary, they will walk and not faint.",
        "Come to Me, all you who are weary and burdened, and I will give you rest.",
        "For the choirmaster. Of the sons of Korah. According to Alamoth. A song. God is our refuge and strength, an ever-present help in times of trouble.",
        "Have I not commanded you to be strong and courageous? Do not be afraid; do not be discouraged, for the LORD your God is with you wherever you go.”",
        "Do not be conformed to this world, but be transformed by the renewing of your mind. Then you will be able to test and approve what is the good, pleasing, and perfect will of God.",
        "I have been crucified with Christ, and I no longer live, but Christ lives in me. The life I live in the body, I live by faith in the Son of God, who loved me and gave Himself up for me.",
        "For it is by grace you have been saved through faith, and this not from yourselves; it is the gift of God,",
        "Therefore if anyone is in Christ, he is a new creation. The old has passed away. Behold, the new has come!",
        "Now faith is the assurance of what we hope for and the certainty of what we do not see.",
        "If we confess our sins, He is faithful and just to forgive us our sins and to cleanse us from all unrighteousness.",
        "Your word is a lamp to my feet and a light to my path.",
        "But seek first the kingdom of God and His righteousness, and all these things will be added unto you.",
        "Jesus answered, “I am the way and the truth and the life. No one comes to the Father except through Me.",
        "But God proves His love for us in this: While we were still sinners, Christ died for us.",
        "Be anxious for nothing, but in everything, by prayer and petition, with thanksgiving, present your requests to God.",
        "Cast all your anxiety on Him, because He cares for you.",
        "They are new every morning; great is Your faithfulness!",
        "Delight yourself in the LORD, and He will give you the desires of your heart.",
        "Do not fear, for I am with you; do not be afraid, for I am your God. I will strengthen you; I will surely help you; I will uphold you with My righteous right hand.",
        "He has shown you, O man, what is good. And what does the LORD require of you but to act justly, to love mercy, and to walk humbly with your God?",
        "Whatever you do, work at it with your whole being, as for the Lord and not for men,",
        "Therefore, since we are surrounded by such a great cloud of witnesses, let us throw off every encumbrance and the sin that so easily entangles, and let us run with endurance the race set out for us.",
        "Now if any of you lacks wisdom, he should ask God, who gives generously to all without finding fault, and it will be given to him.",
        "‘He will wipe away every tear from their eyes,’ and there will be no more death or mourning or crying or pain, for the former things have passed away.”",
        "In the beginning God created the heavens and the earth.",
    ];

    function index() as Lang.Number {
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var doy = Gregorian.moment({:year => info.year, :month => 1, :day => 1});
        var day = (Time.now().subtract(doy) as Time.Duration).value() / 86400;
        return (day % REFS.size()).toNumber();
    }
}
