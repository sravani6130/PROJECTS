/*
 * Licensed to the Apache Software Foundation (ASF) under one or more
 *  contributor license agreements.  The ASF licenses this file to You
 * under the Apache License, Version 2.0 (the "License"); you may not
 * use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.  For additional information regarding
 * copyright in this work, please see the NOTICE file in the top level
 * directory of this distribution.
 */

package org.apache.roller.weblogger.business.search.lucene;

import java.lang.reflect.InvocationTargetException;
import org.apache.commons.beanutils.ConstructorUtils;
import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
import org.apache.lucene.analysis.Analyzer;
import org.apache.lucene.analysis.standard.StandardAnalyzer;
import org.apache.roller.weblogger.config.WebloggerConfig;

/**
 * Factory for creating the Lucene Analyzer used for indexing and searching.
 */
public final class LuceneAnalyzerFactory {

    private static final Log logger = LogFactory.getFactory().getInstance(LuceneAnalyzerFactory.class);

    private LuceneAnalyzerFactory() {
        // utility class
    }

    /**
     * This is the analyzer that will be used to tokenize comment text.
     * 
     * @return Analyzer to be used in manipulating the database.
     */
    public static Analyzer getAnalyzer() {
        return instantiateAnalyzer();
    }

    private static Analyzer instantiateAnalyzer() {
        final String className = WebloggerConfig.getProperty("lucene.analyzer.class");
        try {
            if (className != null && !className.trim().isEmpty()) {
                final Class<?> clazz = Class.forName(className);
                return (Analyzer) ConstructorUtils.invokeConstructor(clazz, null);
            }
        } catch (final ClassNotFoundException e) {
            logger.error("failed to lookup analyzer class: " + className, e);
        } catch (final NoSuchMethodException | InstantiationException | IllegalAccessException
                | InvocationTargetException e) {
            logger.error("failed to instantiate analyzer: " + className, e);
        }
        return instantiateDefaultAnalyzer();
    }

    private static Analyzer instantiateDefaultAnalyzer() {
        return new StandardAnalyzer();
    }
}
