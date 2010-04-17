/*
 *  DDLog.h
 *
 *  Created by Damon Danieli on 4/16/10.
 *  Copyright 2010 Damon Danieli. All rights reserved.
 *
 */

#ifdef DEBUG
#define DDLog(_fmt_, ...) NSLog((@"%s: " _fmt_), __PRETTY_FUNCTION__, ##__VA_ARGS__)
#else
#define DDLog(...)
#endif
