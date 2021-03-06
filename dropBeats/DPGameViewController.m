//
//  DPViewController.m
//  dropBeats
//
//  Created by mmdewitt on 10/19/13.
//  Copyright (c) 2013 Michael Dewitt. All rights reserved.
//

#import "DPGameViewController.h"
#import "DPInstrumentScene.h"
#import "DPTrackScene.h"
#import "InstrumentCell.h"

@interface DPGameViewController() <UICollectionViewDataSource, UICollectionViewDelegate>
{
    #define ANIMATION_DURATION 0.5
    #define DEFAULT_LOCATION CGPointMake(300, 300)
}

@property (weak, nonatomic) IBOutlet SKView *skView;
@property (strong, nonatomic) DPInstrumentScene * skScene;

@property (weak, nonatomic) IBOutlet UIView *bannerView;
@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (weak, nonatomic) IBOutlet UIButton *hideShowButton;

@property (weak, nonatomic) IBOutlet UIButton *playPause;
@property (strong, nonatomic) IBOutlet UIButton *retryBack;

@end

@implementation DPGameViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Configure the view.
//    self.skView.showsFPS = YES;
//    self.skView.showsNodeCount = YES;
//    self.skView.showsDrawCount = YES;
    
    self.collectionView.backgroundColor = [UIColor clearColor];
    
    //Resister for Notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(gameStateChanged:) name:gameStartNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(gameStateChanged:) name:gameEndNotification object:nil];
    
    
    // Create and configure the instrumentScene
    CGSize collectionViewCellSize = IS_IPAD ? CGSizeMake(140,140) : CGSizeMake(100,100);
    self.skScene = [[DPInstrumentScene alloc] initWithSize:self.skView.bounds.size game:self.game andInstrumentSize: collectionViewCellSize];
    self.skScene.scaleMode = SKSceneScaleModeAspectFill;
   
    // Load and present the scene.
    [DPInstrumentScene loadEverythingYouCanWithCompletionHandeler:^{
        [self.skView presentScene:self.skScene];
    }];
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.game endGame];
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - CollectionView Delegate

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return NUMBER_OF_INSTRUMENTS; //defined in InstrumentNode
}

-(UICollectionViewCell*) collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    InstrumentCell* cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"InstrumentCell" forIndexPath:indexPath];
    
    if (cell.panGesture == nil) {
        cell.panGesture = [[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(dragInstrument:)];
        cell.panGesture.cancelsTouchesInView = NO;
        [cell addGestureRecognizer:cell.panGesture];
    }
    
    NSString* imageID = [NSString stringWithFormat:@"%@%d", kInstrumentPrefix, (int)indexPath.row+1];
    NSString *textureName = [NSString stringWithFormat:@"%@_0", imageID];

    cell.imageView.contentMode = UIViewContentModeScaleAspectFit;
    UIImage* image = [UIImage imageNamed:textureName];
    [cell.imageView setImage: image];
    
    return cell;
}

-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    [self.skScene createInstrument:indexPath.row AtLocation: DEFAULT_LOCATION];
}

#pragma mark - Instrument Panel

- (void)dragInstrument:(UIPanGestureRecognizer *)sender {

    InstrumentCell* cell = (InstrumentCell*)sender.view;

    if (sender.state == UIGestureRecognizerStateBegan) {
        CGPoint velocity = [sender velocityInView:self.view];

        NSIndexPath* pathForInstrument = [self.collectionView indexPathForCell: cell];
        CGPoint start = [sender locationInView:self.skScene.view];
        start.y = self.view.frame.size.height - start.y;
      
        if (abs(velocity.y) > abs(velocity.x)){
            cell.hidden = YES;
            [self.skScene createInstrument:pathForInstrument.row AtLocation:start];
        }
    }
    
    [self.skScene handlePan:sender];
    
    if (sender.state == UIGestureRecognizerStateEnded) {
        cell.hidden = NO;
    }
}

- (IBAction)hideShowBanner:(UIButton *)sender
{
    if (!self.displayBanner) {
        
        //Hiding banner
        [UIView animateWithDuration:ANIMATION_DURATION animations:
         ^{
             CGRect frame = self.bannerView.frame;
             frame.origin.x = -self.bannerView.bounds.size.width + (IS_IPAD ? 80 : 20); // to display button
             self.bannerView.frame = frame;
             
         } completion:nil];
        
        [sender setImage:[UIImage imageNamed:@"PullTab.png"] forState:UIControlStateNormal];
//        [self.scene.game startGame];
    }
    else{
        [UIView animateWithDuration:ANIMATION_DURATION animations:
         ^{
             CGRect frame = self.bannerView.frame;
             frame.origin.x = 0;
             self.bannerView.frame = frame;
             
         } completion:nil];
        
        [sender setImage:[UIImage imageNamed:@"PullTab_back.png"] forState:UIControlStateNormal];
        
        if ([self.game isInProgress]) {
            [self.game endGame];
        }
    }
    self.displayBanner = !self.displayBanner;
}

- (IBAction)dragBanner:(UIPanGestureRecognizer *)sender {
    
    CGPoint translation = [sender translationInView:sender.view];
    CGRect frame = self.bannerView.frame;
    
    if (!self.displayBanner) {
        frame.origin.x = translation.x;
        self.bannerView.frame = frame;
    }
    else{
        frame.origin.x = translation.x -frame.size.width;
        self.bannerView.frame = frame;
    }
    
    if (sender.state == UIGestureRecognizerStateEnded) {
        
        if (!self.displayBanner && ( -self.bannerView.frame.origin.x - [sender velocityInView:sender.view].x) < self.collectionView.bounds.size.width/2 ) {
            self.displayBanner = YES;
        }
        else if (self.displayBanner && -self.bannerView.frame.origin.x - [sender velocityInView:sender.view].x > self.collectionView.bounds.size.width/2){
            self.displayBanner = NO;
        }
        [self hideShowBanner:self.hideShowButton];
//        [sender setTranslation:CGPointZero inView:sender.view];
    }
}

#pragma mark - Game Notifications

- (IBAction)resetGame:(UIButton *)sender {
    
    if ([self.game isInProgress]) {
        [self.game endGame];
        
        CABasicAnimation* animation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
        animation.fromValue = @0.0f;
        animation.toValue = @(2*M_PI);
        animation.duration = 0.5f;
        animation.repeatCount = 1;
        [sender.layer addAnimation:animation forKey:@"rotation"];

        [self.game startGame];
    }
    else{
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (IBAction)PlayPause:(UIButton *)sender {
    if (![self.game isInProgress]) {
        [self.game startGame];
        [sender setImage:[UIImage imageNamed:@"Pause.png"] forState:UIControlStateNormal];
    }
    else{
        [self.game endGame];
        [sender setImage:[UIImage imageNamed:@"Play.png"] forState:UIControlStateNormal];
    }
}

-(void)gameStateChanged: (NSNotification *) notification
{
    if ([self.game isInProgress]) {
        [self.retryBack setImage:[UIImage imageNamed:@"Retry.png"] forState:UIControlStateNormal];
        [self.playPause setImage:[UIImage imageNamed:@"Pause.png"] forState:UIControlStateNormal];
        if (!self.displayBanner) {
            [self hideShowBanner:self.hideShowButton];
        }
    }
    else{
        [self.retryBack setImage:nil forState:UIControlStateNormal];
        [self.retryBack setTitle:@" <" forState:UIControlStateNormal];
        self.retryBack.titleLabel.textColor = [UIColor blackColor];
        [self.playPause setImage:[UIImage imageNamed:@"Play.png"] forState:UIControlStateNormal];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    NSLog(@"GAME: MEM. Warning");
}

@end
