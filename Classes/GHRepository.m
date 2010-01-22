#import "GHRepository.h"
#import "iOctocatAppDelegate.h"
#import "GHReposParserDelegate.h"
#import "GHCommitsParserDelegate.h"
#import "GHIssues.h"
#import "GHNetworks.h"


@interface GHRepository ()
- (void)parseXML;
@end


@implementation GHRepository

@synthesize name, owner, descriptionText, githubURL, homepageURL, isPrivate;
@synthesize isFork, forks, watchers, recentCommits, openIssues, closedIssues, networks;

- (id)initWithOwner:(NSString *)theOwner andName:(NSString *)theName {
	[super init];
	[self setOwner:theOwner andName:theName];
	return self;
}

- (void)dealloc {
	[name release];
	[owner release];
	[descriptionText release];
	[githubURL release];
	[homepageURL release];
	[recentCommits release];
    [openIssues release];
    [closedIssues release];
    [networks release];
    [super dealloc];
}

- (NSUInteger)hash {
	NSString *hashValue = [NSString stringWithFormat:@"%@/%@", [owner lowercaseString], [name lowercaseString]];
	return [hashValue hash];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<GHRepository name:'%@' owner:'%@' descriptionText:'%@' githubURL:'%@' homepageURL:'%@' isPrivate:'%@' isFork:'%@' forks:'%d' watchers:'%d'>", name, owner, descriptionText, githubURL, homepageURL, isPrivate ? @"YES" : @"NO", isFork ? @"YES" : @"NO", forks, watchers];
}

- (void)setOwner:(NSString *)theOwner andName:(NSString *)theName {
	self.owner = theOwner;
	self.name = theName;
	// Recent Commits
	NSString *commitFeedURLString = [NSString stringWithFormat:(isPrivate ? kPrivateRepoFeedFormat : kRepoFeedFormat), owner, name];
	NSURL *commitFeedURL = [NSURL URLWithString:commitFeedURLString];
	self.recentCommits = [[[GHFeed alloc] initWithURL:commitFeedURL] autorelease];
    // Networks
    self.networks = [[[GHNetworks alloc] initWithRepository:self] autorelease];
	// Issues
	self.openIssues = [[[GHIssues alloc] initWithRepository:self andState:kIssueStateOpen] autorelease];
	self.closedIssues = [[[GHIssues alloc] initWithRepository:self andState:kIssueStateClosed] autorelease];
}

- (GHUser *)user {
	iOctocatAppDelegate *appDelegate = (iOctocatAppDelegate *)[[UIApplication sharedApplication] delegate];
	return [appDelegate userWithLogin:owner];
}

- (int)compareByName:(GHRepository *)theOtherRepository {
    return [[self name] localizedCaseInsensitiveCompare:[theOtherRepository name]];
}

#pragma mark -
#pragma mark Repository loading

- (void)loadRepository {
	if (self.isLoading) return;
	self.error = nil;
	self.loadingStatus = GHResourceStatusLoading;
	[self performSelectorInBackground:@selector(parseXML) withObject:nil];
}

- (void)parseXML {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSString *url = [NSString stringWithFormat:kRepoXMLFormat, owner, name];
	NSURL *repoURL = [NSURL URLWithString:url];
	ASIFormDataRequest *request = [GHResource authenticatedRequestForURL:repoURL];    
	[request start];
	NSXMLParser *parser = [[NSXMLParser alloc] initWithData:[request responseData]];	
	GHReposParserDelegate *parserDelegate = [[GHReposParserDelegate alloc] initWithTarget:self andSelector:@selector(loadedRepositories:)];
	[parser setDelegate:parserDelegate];
	[parser setShouldProcessNamespaces:NO];
	[parser setShouldReportNamespacePrefixes:NO];
	[parser setShouldResolveExternalEntities:NO];
	[parser parse];
	[parser release];
	[parserDelegate release];
	[pool release];
}

- (void)loadedRepositories:(id)theResult {
	if ([theResult isKindOfClass:[NSError class]]) {
		self.error = theResult;
		self.loadingStatus = GHResourceStatusNotLoaded;
	} else {
		self.loadingStatus = GHResourceStatusLoaded;
		if ([(NSArray *)theResult count] == 0) return;
		GHRepository *repo = [(NSArray *)theResult objectAtIndex:0];
		self.descriptionText = repo.descriptionText;
		self.githubURL = repo.githubURL;
		self.homepageURL = repo.homepageURL;
		self.isFork = repo.isFork;
		self.isPrivate = repo.isPrivate;
		self.forks = repo.forks;
		self.watchers = repo.watchers;
		self.loadingStatus = GHResourceStatusLoaded;
	}
}

@end
